import SwiftUI
@preconcurrency import AVFoundation
import Vision
import UIKit
import Combine

// 카메라와 종이 인식은 전용 큐에서 순서대로 처리한다.
final class FloorPlanImportCamera: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    nonisolated let session = AVCaptureSession()
    nonisolated private let queue = DispatchQueue(label: "sketch.camera")
    nonisolated private let photo = AVCapturePhotoOutput()
    nonisolated private let video = AVCaptureVideoDataOutput()
    nonisolated(unsafe) private var configured = false
    nonisolated(unsafe) private var lastAnalysis = 0.0
    @Published var image: UIImage?
    @Published var message = FloorPlanImportText.adjustPaper
    @Published var ready = false
    @Published var busy = false
    @Published var detected = false
    @Published var zoom = 1.0
    @Published var supportsHalfZoom = false
    nonisolated(unsafe) private var orientation: AVCaptureVideoOrientation = .portrait
    private var autoCapture = true {
        didSet { resetDetection() }
    }
    private var stableSince: Date?
    private var stableCorners: [CGPoint] = []
    private var detectionStartedAt = Date()
    private var previewSize = CGSize.zero
    private var guide = CGRect.zero
    private var isActive = false
    private var startRequest = UUID()

    func start() {
        if isActive {
            return
        }
        // 권한 키가 없으면 카메라를 요청할 때 앱이 종료되므로 확인한다.
        guard Bundle.main.object(forInfoDictionaryKey: "NSCameraUsageDescription") != nil else {
            message = "카메라를 사용할 수 없어요. 카메라 권한 설정을 확인해 주세요."
            return
        }
        autoCapture = true
        isActive = true
        let request = UUID()
        startRequest = request
        Task {
            let allowed = await AVCaptureDevice.requestAccess(for: .video)
            if startRequest != request {
                return
            }
            if isActive == false {
                return
            }
            if allowed == false {
                isActive = false
                message = "설정에서 카메라 접근을 허용해 주세요."
                return
            }
            queue.async { [self] in
                do {
                    if configured == false {
                        session.beginConfiguration()
                        defer { session.commitConfiguration() }
                        session.sessionPreset = .photo
                        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                            throw NSError(domain: "Camera", code: 1, userInfo: [NSLocalizedDescriptionKey: "카메라가 없는 기기입니다. 실제 기기에서 실행해 주세요."])
                        }
                        let input = try AVCaptureDeviceInput(device: camera)
                        guard session.canAddInput(input), session.canAddOutput(photo), session.canAddOutput(video) else {
                            throw NSError(domain: "Camera", code: 2, userInfo: [NSLocalizedDescriptionKey: "카메라를 시작할 수 없습니다."])
                        }
                        session.addInput(input)
                        session.addOutput(photo)
                        session.addOutput(video)
                        video.alwaysDiscardsLateVideoFrames = true
                        video.setSampleBufferDelegate(self, queue: queue)
                        configured = true
                    }
                    if session.isRunning == false {
                        session.startRunning()
                    }
                    DispatchQueue.main.async {
                        if self.startRequest != request {
                            return
                        }
                        if self.isActive == false {
                            return
                        }
                        self.supportsHalfZoom = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) != nil
                        self.resetDetection()
                        self.ready = true
                    }
                } catch {
                    DispatchQueue.main.async {
                        if self.startRequest != request {
                            return
                        }
                        self.isActive = false
                        self.message = error.localizedDescription
                    }
                }
            }
        }
    }
    func stop() {
        isActive = false
        startRequest = UUID()
        ready = false
        stableSince = nil
        stableCorners = []
        queue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }
    // 0.5배는 초광각 렌즈, 나머지는 기본 렌즈의 줌을 사용한다.
    func setZoom(_ value: Double) {
        if ready == false {
            return
        }
        if busy {
            return
        }
        if value == 0.5 {
            if supportsHalfZoom == false {
                return
            }
        }
        ready = false
        resetDetection()
        let request = startRequest
        queue.async { [self] in
            do {
                var cameraType = AVCaptureDevice.DeviceType.builtInWideAngleCamera
                var factor = CGFloat(value)
                if value == 0.5 {
                    cameraType = .builtInUltraWideCamera
                    factor = 1
                }
                guard let device = AVCaptureDevice.default(cameraType, for: .video, position: .back) else {
                    throw NSError(domain: "Camera", code: 3)
                }
                guard let currentInput = session.inputs.first as? AVCaptureDeviceInput else {
                    throw NSError(domain: "Camera", code: 4)
                }
                // 렌즈를 바꾸기 전에 새 입력을 준비해 기존 연결을 유지한다.
                let nextInput = try AVCaptureDeviceInput(device: device)
                try device.lockForConfiguration()
                let actualFactor = min(device.maxAvailableVideoZoomFactor, max(device.minAvailableVideoZoomFactor, factor))
                device.videoZoomFactor = actualFactor
                device.unlockForConfiguration()

                if currentInput.device.uniqueID != device.uniqueID {
                    session.beginConfiguration()
                    session.removeInput(currentInput)
                    if session.canAddInput(nextInput) {
                        session.addInput(nextInput)
                    } else {
                        session.addInput(currentInput)
                        session.commitConfiguration()
                        throw NSError(domain: "Camera", code: 5)
                    }
                    session.commitConfiguration()
                    for output in [photo as AVCaptureOutput, video as AVCaptureOutput] {
                        if let connection = output.connection(with: .video) {
                            if connection.isVideoOrientationSupported {
                                connection.videoOrientation = orientation
                            }
                        }
                    }
                }
                let selectedZoom: Double
                if value == 0.5 {
                    selectedZoom = 0.5
                } else {
                    selectedZoom = Double(actualFactor)
                }
                DispatchQueue.main.async {
                    if self.startRequest != request {
                        return
                    }
                    self.zoom = selectedZoom
                    self.resetDetection()
                    self.ready = self.isActive
                }
            } catch {
                DispatchQueue.main.async {
                    if self.startRequest != request {
                        return
                    }
                    self.message = "줌을 변경하지 못했어요. 다시 선택해 주세요."
                    self.ready = self.isActive
                }
            }
        }
    }

    func capture() {
        if ready == false {
            return
        }
        if busy {
            return
        }
        if image != nil {
            return
        }
        busy = true
        queue.async { self.photo.capturePhoto(with: AVCapturePhotoSettings(), delegate: self) }
    }
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto result: AVCapturePhoto, error: Error?) {
        let data = result.fileDataRepresentation()
        DispatchQueue.main.async {
            self.busy = false
            if self.isActive == false {
                return
            }
            guard error == nil, let data, let image = UIImage(data: data) else {
                self.autoCapture = false
                self.message = FloorPlanImportText.manualCapture
                return
            }
            self.image = image
            self.stop()
        }
    }
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastAnalysis > 0.4, let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastAnalysis = now
        let request = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .up)
        let corners = FloorPlanImportImageProcessor.detectPaper(in: request, allowRectangleFallback: false)
        let imageSize = CGSize(width: CVPixelBufferGetWidth(buffer), height: CVPixelBufferGetHeight(buffer))
        DispatchQueue.main.async {
            self.updateDetection(corners, imageSize: imageSize)
        }
    }

    func updateGuide(previewSize: CGSize, guide: CGRect) {
        if self.previewSize == previewSize {
            if self.guide == guide {
                return
            }
        }
        self.previewSize = previewSize
        self.guide = guide
        resetDetection()
    }

    private func resetDetection() {
        stableSince = nil
        stableCorners = []
        detected = false
        detectionStartedAt = Date()
        showCaptureHint(manual: autoCapture == false)
    }

    private func updateDetection(_ corners: [CGPoint]?, imageSize: CGSize) {
        if ready == false {
            return
        }
        if image != nil {
            return
        }
        if busy {
            return
        }
        let now = Date()
        var manualHint = false
        if autoCapture == false {
            manualHint = true
        } else if now.timeIntervalSince(detectionStartedAt) >= 8 {
            manualHint = true
        }
        detected = corners != nil

        guard let corners, imageSize.width > 0, imageSize.height > 0,
              previewSize.width > 0, previewSize.height > 0,
              guide.width > 0, guide.height > 0 else {
            stableSince = nil
            stableCorners = []
            showCaptureHint(manual: manualHint)
            return
        }

        // 미리보기의 aspectFill 잘림까지 반영해 흰색 가이드 안인지 검사한다.
        let scale = max(previewSize.width / imageSize.width, previewSize.height / imageSize.height)
        let offsetX = (previewSize.width - imageSize.width * scale) / 2
        let offsetY = (previewSize.height - imageSize.height * scale) / 2
        let displayCorners = corners.map {
            CGPoint(x: $0.x * imageSize.width * scale + offsetX,
                    y: $0.y * imageSize.height * scale + offsetY)
        }
        let guidePath = UIBezierPath(roundedRect: guide.insetBy(dx: 4, dy: 4), cornerRadius: 20)
        let fitsGuide = displayCorners.allSatisfy { point in
            guidePath.contains(point)
        }
        let touchesImageEdge = corners.contains { corner in
            if corner.x < 0.015 {
                return true
            }
            if corner.x > 0.985 {
                return true
            }
            if corner.y < 0.015 {
                return true
            }
            if corner.y > 0.985 {
                return true
            }
            return false
        }
        var paperOutsideGuide = false
        if fitsGuide == false {
            paperOutsideGuide = true
        }
        if touchesImageEdge {
            paperOutsideGuide = true
        }
        if paperOutsideGuide {
            stableSince = nil
            stableCorners = []
            message = FloorPlanImportText.fitPaper
            return
        }

        let minX = displayCorners.map { $0.x }.min() ?? 0
        let maxX = displayCorners.map { $0.x }.max() ?? 0
        let minY = displayCorners.map { $0.y }.min() ?? 0
        let maxY = displayCorners.map { $0.y }.max() ?? 0
        let paperArea = (maxX - minX) * (maxY - minY)
        if paperArea < guide.width * guide.height * 0.2 {
            stableSince = nil
            stableCorners = []
            showCaptureHint(manual: manualHint)
            return
        }

        showCaptureHint(manual: manualHint)
        if autoCapture == false {
            return
        }

        // 같은 기준 모서리와 비교하므로 천천히 움직이는 동안에도 촬영하지 않는다.
        var stable = false
        if stableCorners.count == 4 {
            stable = true
            for index in 0..<4 {
                let previous = stableCorners[index]
                let current = corners[index]
                if abs(previous.x - current.x) >= 0.02 {
                    stable = false
                }
                if abs(previous.y - current.y) >= 0.02 {
                    stable = false
                }
            }
        }
        if stable == false {
            stableCorners = corners
            stableSince = now
        }
        if let stableSince, now.timeIntervalSince(stableSince) >= 1.3 {
            capture()
        }
    }
    private func showCaptureHint(manual: Bool) {
        if manual {
            message = FloorPlanImportText.manualCapture
        } else {
            message = FloorPlanImportText.adjustPaper
        }
    }

    func orient(_ orientation: AVCaptureVideoOrientation) {
        queue.async {
            self.orientation = orientation
            for output in [self.photo as AVCaptureOutput, self.video as AVCaptureOutput] {
                if let c = output.connection(with: .video), c.isVideoOrientationSupported {
                    c.videoOrientation = orientation
                }
            }
        }
    }
}

struct FloorPlanImportCameraPreview: UIViewRepresentable {
    let camera: FloorPlanImportCamera
    func makeUIView(context: Context) -> FloorPlanImportPreviewSurface {
        let view = FloorPlanImportPreviewSurface()
        view.camera = camera
        view.preview.session = camera.session
        view.preview.videoGravity = .resizeAspectFill
        return view
    }
    func updateUIView(_ uiView: FloorPlanImportPreviewSurface, context: Context) { uiView.setNeedsLayout() }
}
final class FloorPlanImportPreviewSurface: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var preview: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    weak var camera: FloorPlanImportCamera?
    override func layoutSubviews() {
        super.layoutSubviews()
        guard let orientation = window?.windowScene?.interfaceOrientation,
              let videoOrientation = AVCaptureVideoOrientation(rawValue: orientation.rawValue) else { return }
        if preview.connection?.isVideoOrientationSupported == true {
            preview.connection?.videoOrientation = videoOrientation
        }
        camera?.orient(videoOrientation)
    }
}

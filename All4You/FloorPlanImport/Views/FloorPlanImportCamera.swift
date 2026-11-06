import SwiftUI
import AVFoundation
import Vision
import UIKit
import Combine
import Synchronization

/// 화면에 표시하는 상태는 메인 액터에서만 변경한다.
@MainActor
final class FloorPlanImportCamera: ObservableObject {
    @Published var image: UIImage?
    @Published var message = FloorPlanImportText.adjustPaper
    @Published var ready = false
    @Published var busy = false
    @Published var detected = false
    @Published var zoom = 1.0
    @Published var supportsHalfZoom = false

    private var autoCapture = true
    private var stableSince: Date?
    private var stableCorners: [CGPoint] = []
    private var detectionStartedAt = Date()
    private var previewSize = CGSize.zero
    private var guide = CGRect.zero
    private var isActive = false
    private var startRequest = UUID()
    private var rotationAngle: CGFloat?
    private lazy var worker = FloorPlanImportCameraWorker { [weak self] event in
        self?.receive(event)
    }

    /// 권한을 확인한 뒤 카메라 전용 큐에서 촬영을 준비한다.
    func start() {
        if isActive { return }
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
            if startRequest != request { return }
            if isActive == false { return }
            if allowed == false {
                isActive = false
                message = "설정에서 카메라 접근을 허용해 주세요."
                return
            }
            worker.activeRequest.value.withLock { $0 = request }
            await worker.start(request: request)
        }
    }

    /// 화면을 떠나면 이전 요청을 무효화하고 카메라를 중지한다.
    func stop() {
        isActive = false
        startRequest = UUID()
        ready = false
        busy = false
        stableSince = nil
        stableCorners = []
        worker.activeRequest.value.withLock { $0 = nil }
        Task { await worker.stop() }
    }

    /// 선택한 배율을 카메라에 전달한다. 0.5배는 초광각 지원 기기에서만 가능하다.
    func setZoom(_ value: Double) {
        if ready == false { return }
        if busy { return }
        if value == 0.5 {
            if supportsHalfZoom == false { return }
        }
        ready = false
        resetDetection()
        let request = startRequest
        Task { await worker.setZoom(value, request: request) }
    }

    /// 버튼 또는 자동 인식으로 사진 한 장을 촬영한다.
    func capture() {
        if ready == false { return }
        if busy { return }
        if image != nil { return }
        busy = true
        let request = startRequest
        Task { await worker.capture(request: request) }
    }

    /// 작업 결과만 메인 액터로 받아 화면 상태에 반영한다.
    private func receive(_ event: FloorPlanImportCameraEvent) {
        if event.request != startRequest { return }
        if isActive == false { return }
        switch event.result {
        case .started(let supportsHalfZoom):
            self.supportsHalfZoom = supportsHalfZoom
            resetDetection()
            ready = true
        case .zoomed(let value):
            zoom = value
            resetDetection()
            ready = true
        case .zoomFailed:
            message = "줌을 변경하지 못했어요. 다시 선택해 주세요."
            ready = true
        case .photo(let data):
            busy = false
            if let data, let capturedImage = UIImage(data: data) {
                image = capturedImage
                stop()
            } else {
                autoCapture = false
                resetDetection()
            }
        case .detection(let corners, let size):
            updateDetection(corners, imageSize: size)
        case .failed(let explanation):
            isActive = false
            ready = false
            message = explanation
        }
    }

    /// 화면에 표시된 흰색 프레임의 위치와 크기를 인식 기준으로 저장한다.
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

    /// 이전 종이 위치와 대기 시간을 지우고 새로 인식을 시작할 준비를 한다.
    private func resetDetection() {
        stableSince = nil
        stableCorners = []
        detected = false
        detectionStartedAt = Date()
        showCaptureHint(manual: autoCapture == false)
    }

    /// 종이가 프레임 안에 있는지와 흔들림을 확인하고, 안정되면 자동 촬영한다.
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
    /// 자동 촬영을 기다리는 안내 또는 직접 촬영 안내를 표시한다.
    private func showCaptureHint(manual: Bool) {
        if manual {
            message = FloorPlanImportText.manualCapture
        } else {
            message = FloorPlanImportText.adjustPaper
        }
    }

    /// 미리보기 연결은 UIKit이 요구하는 메인 액터에서 수행한다.
    func connectPreview(_ preview: AVCaptureVideoPreviewLayer) {
        worker.previewSession.withLock { session in
            preview.session = session
        }
    }

    /// 방향이 바뀐 경우에만 같은 회전 각도를 사진과 분석 영상에 전달한다.
    func orient(_ angle: CGFloat) {
        if rotationAngle == angle { return }
        rotationAngle = angle
        Task { await worker.orient(angle) }
    }
}

/// 액터 사이에는 장비 객체 대신 사진 데이터와 숫자 등 결과 값만 전달한다.
private struct FloorPlanImportCameraEvent: Sendable {
    let request: UUID
    let result: Result

    enum Result: Sendable {
        case started(Bool)
        case zoomed(Double)
        case zoomFailed
        case photo(Data?)
        case detection([CGPoint]?, CGSize)
        case failed(String)
    }
}

/// 요청 번호는 UI, 카메라 액터, 영상 콜백이 함께 사용하므로 락으로 보호한다.
private final class FloorPlanImportCameraRequest: Sendable {
    let value = Mutex<UUID?>(nil)
}

/// 카메라 장비의 설정·시작·정지·촬영을 한 액터에서 순서대로 처리한다.
private actor FloorPlanImportCameraWorker {
    let activeRequest: FloorPlanImportCameraRequest
    // 미리보기 연결만 메인 액터에서도 필요하므로 세션은 락을 통해 접근한다.
    let previewSession = Mutex(AVCaptureSession())
    private let photo = AVCapturePhotoOutput()
    private let video = AVCaptureVideoDataOutput()
    private let analysisQueue = DispatchQueue(label: "floorplan.analysis")
    private let delegate: FloorPlanImportCameraDelegate
    private let onEvent: @MainActor @Sendable (FloorPlanImportCameraEvent) -> Void
    private var rotationAngle: CGFloat = 90

    @MainActor
    init(onEvent: @escaping @MainActor @Sendable (FloorPlanImportCameraEvent) -> Void) {
        let request = FloorPlanImportCameraRequest()
        activeRequest = request
        delegate = FloorPlanImportCameraDelegate(request: request, onEvent: onEvent)
        self.onEvent = onEvent
    }

    /// 세션 시작은 메인 액터 밖에서 실행해 화면을 멈추지 않는다.
    func start(request: UUID) {
        if activeRequest.value.withLock({ $0 != request }) { return }
        do {
            let supportsHalfZoom = try previewSession.withLock { session in
                if session.inputs.isEmpty { try configure(session) }
                if session.isRunning == false { session.startRunning() }
                return AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) != nil
            }
            send(request, .started(supportsHalfZoom))
        } catch {
            send(request, .failed(error.localizedDescription))
        }
    }

    /// 처음 한 번 카메라 입력과 사진·영상 출력을 연결한다.
    private func configure(_ session: AVCaptureSession) throws {
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CameraError.unavailable
        }
        let input = try AVCaptureDeviceInput(device: camera)
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo
        guard session.canAddInput(input) else { throw CameraError.configuration }
        session.addInput(input)
        guard session.canAddOutput(photo) else {
            session.removeInput(input)
            throw CameraError.configuration
        }
        session.addOutput(photo)
        guard session.canAddOutput(video) else {
            session.removeOutput(photo)
            session.removeInput(input)
            throw CameraError.configuration
        }
        session.addOutput(video)
        video.alwaysDiscardsLateVideoFrames = true
        video.setSampleBufferDelegate(delegate, queue: analysisQueue)
        applyRotation()
    }

    /// 새 촬영 화면이 이미 시작됐다면 이전 중지 요청은 무시한다.
    func stop() {
        if activeRequest.value.withLock({ $0 != nil }) { return }
        previewSession.withLock { session in
            if session.isRunning { session.stopRunning() }
        }
    }

    /// 렌즈 전환과 배율 변경은 액터 안에서 순서대로 수행한다.
    func setZoom(_ value: Double, request: UUID) {
        if activeRequest.value.withLock({ $0 != request }) { return }
        do {
            let selectedZoom = try previewSession.withLock { session in
                var cameraType = AVCaptureDevice.DeviceType.builtInWideAngleCamera
                var factor = CGFloat(value)
                if value == 0.5 {
                    cameraType = .builtInUltraWideCamera
                    factor = 1
                }
                guard let device = AVCaptureDevice.default(cameraType, for: .video, position: .back),
                      let current = session.inputs.first as? AVCaptureDeviceInput else {
                    throw CameraError.unavailable
                }
                try device.lockForConfiguration()
                let actual = min(device.maxAvailableVideoZoomFactor, max(device.minAvailableVideoZoomFactor, factor))
                device.videoZoomFactor = actual
                device.unlockForConfiguration()
                if current.device.uniqueID != device.uniqueID {
                    let next = try AVCaptureDeviceInput(device: device)
                    session.beginConfiguration()
                    session.removeInput(current)
                    if session.canAddInput(next) {
                        session.addInput(next)
                    } else {
                        session.addInput(current)
                        session.commitConfiguration()
                        throw CameraError.configuration
                    }
                    session.commitConfiguration()
                    applyRotation()
                }
                if value == 0.5 { return 0.5 }
                return Double(actual)
            }
            send(request, .zoomed(selectedZoom))
        } catch {
            send(request, .zoomFailed)
        }
    }

    /// 촬영 번호에 화면 요청을 연결해 이전 촬영 결과와 섞이지 않게 한다.
    func capture(request: UUID) {
        if activeRequest.value.withLock({ $0 != request }) { return }
        let settings = AVCapturePhotoSettings()
        delegate.photoRequests.withLock { $0[settings.uniqueID] = request }
        photo.capturePhoto(with: settings, delegate: delegate)
    }

    /// 영상과 사진의 회전 각도도 액터 안에서 변경한다.
    func orient(_ angle: CGFloat) {
        rotationAngle = angle
        applyRotation()
    }

    private func applyRotation() {
        for output in [photo as AVCaptureOutput, video as AVCaptureOutput] {
            if let connection = output.connection(with: .video) {
                if connection.isVideoRotationAngleSupported(rotationAngle) {
                    if connection.videoRotationAngle != rotationAngle {
                        connection.videoRotationAngle = rotationAngle
                    }
                }
            }
        }
    }

    private func send(_ request: UUID, _ result: FloorPlanImportCameraEvent.Result) {
        let event = FloorPlanImportCameraEvent(request: request, result: result)
        Task { @MainActor in onEvent(event) }
    }

    private enum CameraError: LocalizedError {
        case unavailable, configuration
        var errorDescription: String? {
            switch self {
            case .unavailable: "카메라를 사용할 수 없어요. 실제 기기에서 확인해 주세요."
            case .configuration: "카메라를 시작할 수 없습니다. 다시 시도해 주세요."
            }
        }
    }
}

/// AVFoundation 콜백은 화면 상태를 직접 변경하지 않고, 보호된 값과 결과만 다룬다.
// AVFoundation이 자체 큐에서 호출하므로 메인 액터에 묶지 않는다.
// 안전성 검사를 끄는 선언이 아니라, Mutex로 보호되는 Sendable 콜백 수신기다.
nonisolated private final class FloorPlanImportCameraDelegate: NSObject, Sendable,
    AVCapturePhotoCaptureDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    let photoRequests = Mutex<[Int64: UUID]>([:])
    private let lastAnalysis = Mutex(0.0)
    private let request: FloorPlanImportCameraRequest
    private let onEvent: @MainActor @Sendable (FloorPlanImportCameraEvent) -> Void

    init(request: FloorPlanImportCameraRequest,
         onEvent: @escaping @MainActor @Sendable (FloorPlanImportCameraEvent) -> Void) {
        self.request = request
        self.onEvent = onEvent
        super.init()
    }

    /// 사진 데이터만 메인 액터로 보낸다. 장비 객체는 액터 밖으로 전달하지 않는다.
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let id = photoRequests.withLock { $0.removeValue(forKey: photo.resolvedSettings.uniqueID) }
        guard let id else { return }
        var data: Data?
        if error == nil { data = photo.fileDataRepresentation() }
        let event = FloorPlanImportCameraEvent(request: id, result: .photo(data))
        Task { @MainActor in onEvent(event) }
    }

    /// 사진 처리 없이 실패한 경우에도 촬영 중 상태를 해제한다.
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor settings: AVCaptureResolvedPhotoSettings, error: Error?) {
        if error == nil { return }
        let id = photoRequests.withLock { $0.removeValue(forKey: settings.uniqueID) }
        guard let id else { return }
        let event = FloorPlanImportCameraEvent(request: id, result: .photo(nil))
        Task { @MainActor in onEvent(event) }
    }

    /// 분석 시간만 잠깐 잠그고, 문서 분석은 전용 큐에서 수행한다.
    func captureOutput(_ output: AVCaptureOutput, didOutput buffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let id = request.value.withLock({ $0 }) else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let shouldAnalyze = lastAnalysis.withLock { previous in
            if now - previous < 0.4 { return false }
            previous = now
            return true
        }
        if shouldAnalyze == false { return }
        guard let pixels = CMSampleBufferGetImageBuffer(buffer) else { return }
        let handler = VNImageRequestHandler(cvPixelBuffer: pixels, orientation: .up)
        let corners = FloorPlanImportImageProcessor.detectPaper(in: handler, allowRectangleFallback: false)
        let size = CGSize(width: CVPixelBufferGetWidth(pixels), height: CVPixelBufferGetHeight(pixels))
        let event = FloorPlanImportCameraEvent(request: id, result: .detection(corners, size))
        Task { @MainActor in onEvent(event) }
    }
}

struct FloorPlanImportCameraPreview: UIViewRepresentable {
    let camera: FloorPlanImportCamera
    /// 카메라 영상을 보여줄 UIKit 뷰를 만들고 카메라 세션을 연결한다.
    func makeUIView(context: Context) -> FloorPlanImportPreviewSurface {
        let view = FloorPlanImportPreviewSurface()
        view.camera = camera
        camera.connectPreview(view.preview)
        view.preview.videoGravity = .resizeAspectFill
        return view
    }
    /// SwiftUI 화면이 갱신되면 카메라 뷰의 배치와 방향도 다시 확인하도록 요청한다.
    func updateUIView(_ uiView: FloorPlanImportPreviewSurface, context: Context) { uiView.setNeedsLayout() }
}
final class FloorPlanImportPreviewSurface: UIView {
    /// 이 뷰의 바탕에 일반 레이어 대신 카메라 영상 전용 레이어를 사용한다.
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    /// 뷰의 레이어를 카메라 미리보기 레이어로 꺼낸다. 위의 layerClass가 타입을 보장한다.
    var preview: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    weak var camera: FloorPlanImportCamera?
    /// 뷰가 배치되거나 회전하면 미리보기와 실제 촬영 방향을 함께 맞춘다.
    override func layoutSubviews() {
        super.layoutSubviews()
        guard let orientation = window?.windowScene?.effectiveGeometry.interfaceOrientation else { return }

        // 후면 카메라의 기본 방향을 기준으로 화면에 필요한 회전 각도를 구한다.
        let angle: CGFloat
        switch orientation {
        case .portrait:
            angle = 90
        case .portraitUpsideDown:
            angle = 270
        case .landscapeLeft:
            angle = 180
        case .landscapeRight:
            angle = 0
        default:
            return
        }

        if let connection = preview.connection {
            if connection.isVideoRotationAngleSupported(angle) {
                if connection.videoRotationAngle != angle {
                    connection.videoRotationAngle = angle
                }
            }
        }
        camera?.orient(angle)
    }
}

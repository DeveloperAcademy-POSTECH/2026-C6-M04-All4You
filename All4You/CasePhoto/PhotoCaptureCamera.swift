//
//  PhotoCaptureCamera.swift
//  All4You
//
//  Created by SIA on 11/9/26.
//

// 사진 촬영 화면의 카메라. 세션을 켜고 끄고, 사진 한 장을 찍어 돌려준다
// 화면 상태를 들고 있지 않고 애플 카메라 기능과 잇기만 한다 (UIKit 연결과 같은 성격)

import AVFoundation
import UIKit

/// 찍은 사진 한 장과 목록용 작은 사진
struct CapturedPhoto {
    let image: UIImage
    let thumbnail: UIImage
}

/// 후면 광각 카메라로 사진을 찍는다.
/// 세션 설정·시작·중지는 시간이 걸려 화면이 멈추지 않도록 카메라 전용 큐에서 한다
final class PhotoCaptureCamera: NSObject {
    let session = AVCaptureSession()
    /// 이 기기에서 쓸 카메라. 시뮬레이터처럼 카메라가 없으면 nil
    let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)

    private let output = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "PhotoCaptureCamera.session")
    private var isConfigured = false

    /// 기기를 돌려도 사진·미리보기가 바로 서도록 각도를 알려 주는 계산기. 미리보기가 붙으면 만든다
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var previewRotationObservation: NSKeyValueObservation?
    private weak var previewLayer: AVCaptureVideoPreviewLayer?

    /// 찍는 중인 사진의 답을 기다리는 곳. 사진 설정의 uniqueID로 찾는다.
    /// 사진 답(delegate)은 아무 스레드에서나 와서 잠금으로 지킨다
    private var pendingCaptures: [Int64: CheckedContinuation<CapturedPhoto?, Never>] = [:]
    private let pendingLock = NSLock()

    var isAvailable: Bool { device != nil }

    /// 세션을 설정하고 켠다
    func start() {
        sessionQueue.async { [self] in
            configureIfNeeded()
            guard isConfigured, !session.isRunning else { return }
            session.startRunning()
            // 세션이 켜진 뒤에야 미리보기 연결이 생겨 각도를 다시 맞춘다
            Task { @MainActor [self] in
                applyPreviewRotation()
            }
        }
    }

    func stop() {
        sessionQueue.async { [self] in
            guard session.isRunning else { return }
            session.stopRunning()
        }
    }

    /// 미리보기 레이어를 붙이고, 기기 방향이 바뀔 때마다 미리보기 각도를 맞춘다
    @MainActor
    func attachPreview(_ layer: AVCaptureVideoPreviewLayer) {
        previewLayer = layer
        guard let device else { return }
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: layer)
        rotationCoordinator = coordinator
        previewRotationObservation = coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.applyPreviewRotation()
            }
        }
        applyPreviewRotation()
    }

    /// 사진 한 장을 찍어 돌려준다. 찍지 못하면 nil
    @MainActor
    func capturePhoto() async -> CapturedPhoto? {
        let angle = rotationCoordinator?.videoRotationAngleForHorizonLevelCapture
        return await withCheckedContinuation { continuation in
            sessionQueue.async { [self] in
                guard session.isRunning else {
                    continuation.resume(returning: nil)
                    return
                }
                if let angle, let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(angle) {
                    connection.videoRotationAngle = angle
                }
                let settings = AVCapturePhotoSettings()
                pendingLock.withLock {
                    pendingCaptures[settings.uniqueID] = continuation
                }
                output.capturePhoto(with: settings, delegate: self)
            }
        }
    }
}

// 설정
extension PhotoCaptureCamera {
    /// 처음 한 번만 카메라 입력과 사진 출력을 세션에 붙인다. 카메라 큐에서만 부른다
    private func configureIfNeeded() {
        guard !isConfigured, let device, let input = try? AVCaptureDeviceInput(device: device) else { return }
        session.beginConfiguration()
        session.sessionPreset = .photo
        if session.canAddInput(input) {
            session.addInput(input)
        }
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.maxPhotoQualityPrioritization = .balanced
        }
        session.commitConfiguration()
        isConfigured = true
    }

    @MainActor
    private func applyPreviewRotation() {
        guard let angle = rotationCoordinator?.videoRotationAngleForHorizonLevelPreview,
              let connection = previewLayer?.connection,
              connection.isVideoRotationAngleSupported(angle) else { return }
        connection.videoRotationAngle = angle
    }
}

// 사진 답
extension PhotoCaptureCamera: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let continuation = pendingLock.withLock {
            pendingCaptures.removeValue(forKey: photo.resolvedSettings.uniqueID)
        }
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            continuation?.resume(returning: nil)
            return
        }
        // 이미 카메라 쪽 스레드라 여기서 작은 사진까지 만들어 화면이 멈추지 않게 한다
        let thumbnail = EvidencePhoto.makeThumbnail(from: image)
        continuation?.resume(returning: CapturedPhoto(image: image, thumbnail: thumbnail))
    }
}

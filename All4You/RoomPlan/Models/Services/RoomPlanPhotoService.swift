//
//  RoomPlanPhotoService.swift
//  All4You
//
//  Created by SIA on 11/10/26.
//

// RoomPlan이 돌고 있는 ARSession에서 사진을 찍고, 그 순간의 카메라 자세를 함께 보관하는 로직
//
// 1) ARSession.captureHighResolutionFrame으로 고화질 프레임을 받는다 (안 되면 현재 프레임). 사진과 자세가 같은 프레임에서 나온다
// 2) 찍은 자리에 ARAnchor를 하나 둔다. ARKit이 지도를 다듬으면(루프 클로저 등) 앵커도 따라 움직이고, 월드맵에도 저장돼 재현지화 뒤에도 남는다
// 3) 스캔을 마칠 때 앵커의 마지막 위치로 자세를 고친다

import ARKit
import CoreImage
import Foundation
import OSLog
import UIKit

@MainActor final class RoomPlanPhotoService {
    nonisolated enum CaptureError: LocalizedError {
        case noFrame
        case renderFailed

        var errorDescription: String? {
            switch self {
            case .noFrame: "카메라 화면을 아직 받지 못했어요"
            case .renderFailed: "사진을 만들지 못했어요"
            }
        }
    }

    private(set) var photos: [ScanPhoto] = []
    private let logger = Logger(subsystem: "All4You", category: "RoomPlanPhoto")

    /// 앵커 이름 앞부분. 사진 id를 뒤에 붙여 앵커 ↔ 사진을 잇는다
    private static let anchorPrefix = "scanPhoto:"

    /// 지금 프레임을 사진으로 찍고 자세와 함께 보관한다
    @discardableResult
    func capture(from session: ARSession, orientation: UIInterfaceOrientation) async throws -> ScanPhoto {
        let frame = try await highResolutionFrame(from: session)
        let camera = frame.camera
        let id = UUID()
        let isTrackingNormal: Bool = if case .normal = camera.trackingState { true } else { false }
        let pose = ScanCameraPose(
            transform: camera.transform,
            intrinsics: camera.intrinsics,
            imageResolution: camera.imageResolution,
            isTrackingNormal: isTrackingNormal
        )
        // 앵커는 자세가 정해진 프레임 기준으로 바로 둔다 (사진 변환을 기다리지 않음)
        session.add(anchor: ARAnchor(name: Self.anchorPrefix + id.uuidString, transform: camera.transform))

        let pixelBuffer = frame.capturedImage
        let imageOrientation = orientation.imageOrientation
        let (imageData, thumbnailData) = try await Task.detached(priority: .userInitiated) {
            try Self.encode(pixelBuffer, orientation: imageOrientation)
        }.value

        let photo = ScanPhoto(id: id, takenAt: .now, imageData: imageData, thumbnailData: thumbnailData, pose: pose)
        photos.append(photo)
        return photo
    }

    /// ARKit이 다듬은 앵커 위치로 사진 자세를 고친다. 앵커가 없어진 사진은 찍을 때 값을 그대로 둔다
    func refreshPoses(from session: ARSession) {
        guard let anchors = session.currentFrame?.anchors else { return }
        var transforms: [UUID: simd_float4x4] = [:]
        for anchor in anchors {
            guard let name = anchor.name, name.hasPrefix(Self.anchorPrefix),
                  let id = UUID(uuidString: String(name.dropFirst(Self.anchorPrefix.count))) else { continue }
            transforms[id] = anchor.transform
        }
        for index in photos.indices {
            guard let transform = transforms[photos[index].id] else { continue }
            photos[index].pose?.worldTransform = transform
        }
    }

    /// ARSession을 버려 좌표계가 바뀌면 이전 자세는 쓸 수 없다. 사진은 남기고 자세만 지운다 (위치 미지정으로 들어감)
    func invalidatePoses() {
        guard photos.contains(where: { $0.pose != nil }) else { return }
        logger.notice("AR 좌표계 초기화로 사진 \(self.photos.count)장의 촬영 위치를 지웁니다")
        for index in photos.indices { photos[index].pose = nil }
    }

    // 고화질 캡처는 RoomPlan이 고른 영상 형식에 따라 안 될 수 있다. 실패하면 화면에 쓰는 현재 프레임으로 찍는다
    private func highResolutionFrame(from session: ARSession) async throws -> ARFrame {
        do {
            return try await withCheckedThrowingContinuation { continuation in
                session.captureHighResolutionFrame { frame, error in
                    if let frame {
                        continuation.resume(returning: frame)
                    } else {
                        continuation.resume(throwing: error ?? CaptureError.noFrame)
                    }
                }
            }
        } catch {
            logger.notice("고화질 프레임 캡처 실패, 현재 프레임 사용: \(error.localizedDescription, privacy: .public)")
            guard let frame = session.currentFrame else { throw CaptureError.noFrame }
            return frame
        }
    }

    /// 픽셀 버퍼를 화면 방향으로 돌려 원본·작은 사진 JPEG로 만든다
    private nonisolated static func encode(_ pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) throws -> (Data, Data) {
        let image = CIImage(cvPixelBuffer: pixelBuffer).oriented(orientation)
        guard let cgImage = imageContext.createCGImage(image, from: image.extent) else { throw CaptureError.renderFailed }
        let uiImage = UIImage(cgImage: cgImage)
        let longest = max(uiImage.size.width, uiImage.size.height)
        let ratio = min(1, thumbnailLength / longest)
        let thumbnail = uiImage.preparingThumbnail(of: CGSize(width: uiImage.size.width * ratio, height: uiImage.size.height * ratio)) ?? uiImage
        guard let imageData = uiImage.jpegData(compressionQuality: jpegQuality),
              let thumbnailData = thumbnail.jpegData(compressionQuality: jpegQuality) else { throw CaptureError.renderFailed }
        return (imageData, thumbnailData)
    }

    // CIContext는 여러 스레드에서 써도 안전하다 (Core Image 문서)
    private nonisolated(unsafe) static let imageContext = CIContext()
    /// PhotoStore와 같은 값: 작은 사진 긴 변 480px, JPEG 품질 0.9
    private nonisolated static let thumbnailLength: CGFloat = 480
    private nonisolated static let jpegQuality: CGFloat = 0.9
}

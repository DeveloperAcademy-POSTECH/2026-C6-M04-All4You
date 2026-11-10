//
//  ScanPhoto.swift
//  All4You
//
//  Created by SIA on 11/10/26.
//

// 공간 스캔(RoomPlan) 도중 찍은 사진과, 그 순간 ARKit(VIO)이 알고 있던 카메라 자세
// RoomPlan과 같은 ARSession의 월드 좌표라 CapturedRoom·CapturedStructure의 벽과 같은 좌표계에 있다

import Foundation
import simd
import UIKit

/// 스캔 중 찍은 사진 한 장. 4K 프레임을 UIImage로 여러 장 들고 있으면 메모리가 부족해 찍자마자 JPEG로 바꿔 둔다
nonisolated struct ScanPhoto: Identifiable, Sendable {
    let id: UUID
    let takenAt: Date
    /// 원본 JPEG
    let imageData: Data
    /// 목록·도면 핀용 작은 JPEG
    let thumbnailData: Data
    /// 찍은 순간의 카메라 자세. 좌표계가 버려지면(빈 스캔 초기화) nil
    var pose: ScanCameraPose?
}

/// ARKit 월드 좌표의 카메라 자세. 단위 m, +y가 위(중력 반대)
nonisolated struct ScanCameraPose: Codable, Hashable, Sendable {
    /// ARCamera.transform (열 우선 16개)
    var transform: [Float]
    /// ARCamera.intrinsics (열 우선 9개). 센서 원본 해상도 기준
    var intrinsics: [Float]
    /// intrinsics가 기준으로 삼는 센서 이미지 크기 (px, 가로가 긴 쪽)
    var imageWidth: Int
    var imageHeight: Int
    /// 찍을 때 추적 상태가 정상이었는지. 아니면 위치를 믿지 않는다
    var isTrackingNormal: Bool

    init(transform: simd_float4x4, intrinsics: simd_float3x3, imageResolution: CGSize, isTrackingNormal: Bool) {
        self.transform = []
        self.intrinsics = [intrinsics.columns.0, intrinsics.columns.1, intrinsics.columns.2]
            .flatMap { [$0.x, $0.y, $0.z] }
        self.imageWidth = Int(imageResolution.width)
        self.imageHeight = Int(imageResolution.height)
        self.isTrackingNormal = isTrackingNormal
        self.worldTransform = transform
    }

    var worldTransform: simd_float4x4 {
        get {
            let t = transform
            return simd_float4x4(
                SIMD4(t[0], t[1], t[2], t[3]),
                SIMD4(t[4], t[5], t[6], t[7]),
                SIMD4(t[8], t[9], t[10], t[11]),
                SIMD4(t[12], t[13], t[14], t[15])
            )
        }
        set {
            transform = [newValue.columns.0, newValue.columns.1, newValue.columns.2, newValue.columns.3]
                .flatMap { [$0.x, $0.y, $0.z, $0.w] }
        }
    }

    /// 카메라 위치 (월드, m)
    var position: SIMD3<Double> {
        let p = worldTransform.columns.3
        return SIMD3(Double(p.x), Double(p.y), Double(p.z))
    }

    /// 카메라가 보는 방향 (월드 단위 벡터). ARKit 카메라는 자기 -Z 축을 본다
    var forward: SIMD3<Double> {
        let z = worldTransform.columns.2
        return simd_normalize(-SIMD3(Double(z.x), Double(z.y), Double(z.z)))
    }

    /// 위아래 기울기 (도). 수평 0°, 위를 보면 +
    var pitch: Double {
        asin(min(max(forward.y, -1), 1)) * 180 / .pi
    }

    /// 센서 긴 변 방향 화각 (도)
    var horizontalFieldOfView: Double {
        let fx = Double(intrinsics[0])
        guard fx > 0 else { return 60 }
        return 2 * atan(Double(imageWidth) / (2 * fx)) * 180 / .pi
    }
}

/// 사진이 도면 위 어디서 어느 쪽을 보고 찍혔는지 (도면 좌표)
nonisolated struct PhotoPlacement: Codable, Hashable, Sendable {
    /// 카메라 위치 (도면 좌표, m)
    var position: SIMD2<Double>
    /// 바라보는 방향 (도). 도면 위쪽이 0°, 시계 방향 (PlanMarker.yaw와 같은 규칙).
    /// 바닥·천장을 거의 수직으로 찍어 수평 방향이 없으면 nil
    var yaw: Double?
    /// 위아래 기울기 (도). 수평 0°, 위를 보면 +
    var pitch: Double
    /// 바닥에서 카메라 높이 (m)
    var height: Double
    /// 화각 (도)
    var fieldOfView: Double
}

/// RoomPlan 월드 좌표 → 도면 좌표 변환. 스캔을 도면으로 바꿀 때(PlanData+Scan) 쓴 회전·이동을 그대로 담는다
nonisolated struct ScanAlignment: Codable, Hashable, Sendable {
    /// 월드 (x, z)를 돌리는 각 (라디안)
    var angle: Double
    /// 돌린 뒤 더하는 이동 (m)
    var shift: SIMD2<Double>
    /// 월드 y에서 바닥 높이 (m)
    var floorHeight: Double

    func planPoint(_ world: SIMD3<Double>) -> SIMD2<Double> {
        rotate(SIMD2(world.x, world.z)) + shift
    }

    /// 월드 방향의 수평 성분을 도면 yaw(도)로. 수평 성분이 거의 없으면 nil
    func planYaw(of worldDirection: SIMD3<Double>) -> Double? {
        let horizontal = SIMD2(worldDirection.x, worldDirection.z)
        guard simd_length(horizontal) > 0.15 else { return nil }
        let d = rotate(horizontal)
        // 도면은 +y가 아래: 위(0, -1) = 0°, 오른쪽(1, 0) = 90°
        let degrees = atan2(d.x, -d.y) * 180 / .pi
        return degrees < 0 ? degrees + 360 : degrees
    }

    /// 카메라 자세를 도면 위 자리로. 추적이 불안정했던 사진은 nil
    func placement(of pose: ScanCameraPose) -> PhotoPlacement? {
        guard pose.isTrackingNormal else { return nil }
        return PhotoPlacement(
            position: planPoint(pose.position),
            yaw: planYaw(of: pose.forward),
            pitch: pose.pitch,
            height: pose.position.y - floorHeight,
            fieldOfView: pose.horizontalFieldOfView
        )
    }

    private func rotate(_ p: SIMD2<Double>) -> SIMD2<Double> {
        SIMD2(p.x * cos(angle) - p.y * sin(angle), p.x * sin(angle) + p.y * cos(angle))
    }
}

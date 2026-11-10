// SwiftData에 저장하는 현장 사진 모델. 사진 이미지는 큰 데이터라 SwiftData가 파일로 따로 보관한다(externalStorage)

import Foundation
import SwiftData

/// 사건에서 찍거나 불러온 사진 한 장
@Model
final class EvidencePhoto {
    @Attribute(.unique) var id: UUID
    /// 가져온 경로 (앱 카메라·사진 앱)
    var source: PhotoSource
    var isBookmarked: Bool
    /// 사진이 찍힌 장소 (planData `rooms[].id`). nil이면 아직 장소를 정하지 않은 사진
    var roomKey: String?
    /// 찍은 시각. 불러온 사진은 사진 앱에 남아 있는 촬영 시각. 앨범을 달별로 묶을 때 쓴다
    var takenAt: Date
    /// 원본 이미지(JPEG). 마크업하면 마크업이 그려진 사진으로 바뀐다
    @Attribute(.externalStorage) var imageData: Data
    /// 목록·도면 핀에 쓰는 작은 이미지(JPEG). 원본을 목록마다 읽으면 느려서 따로 둔다
    @Attribute(.externalStorage) var thumbnailData: Data
    /// 이 사진이 속한 사건. 반대쪽은 `FireCase.photos`
    var fireCase: FireCase?
    /// 찍은 조사 차수. 없을 수 있다. 반대쪽은 `InvestigationSession.photos`
    var session: InvestigationSession?
    /// AR로 찍은 사진의 카메라 자세(ScanCameraPose JSON, ARKit 월드 좌표). 앱 일반 카메라·사진 앱 사진은 nil.
    /// 도면의 scanAlignment와 함께 도면 위 촬영 위치·방향을 다시 계산할 때 쓴다 (`placement(in:)`)
    var cameraPoseData: Data?
    /// 도면 위 촬영 위치 X (planData 좌표, m). 위치를 모르면 nil
    var positionX: Double?
    /// 도면 위 촬영 위치 Y (planData 좌표, m, 아래쪽이 +)
    var positionY: Double?
    /// 바닥에서 촬영 높이 (m)
    var positionZ: Double?
    /// 촬영 방향 (yaw, 도). 도면 위쪽이 0°, 시계 방향 (PlanMarker.yaw와 같은 규칙). 방향을 모르면 nil
    var direction: Double?

    init(
        id: UUID = UUID(),
        source: PhotoSource,
        isBookmarked: Bool = false,
        roomKey: String? = nil,
        takenAt: Date,
        imageData: Data,
        thumbnailData: Data,
        session: InvestigationSession? = nil,
        cameraPoseData: Data? = nil,
        placement: SavedPlacement? = nil
    ) {
        self.id = id
        self.source = source
        self.isBookmarked = isBookmarked
        self.roomKey = roomKey
        self.takenAt = takenAt
        self.imageData = imageData
        self.thumbnailData = thumbnailData
        self.session = session
        self.cameraPoseData = cameraPoseData
        self.positionX = placement?.position.x
        self.positionY = placement?.position.y
        self.positionZ = placement?.height
        self.direction = placement?.direction
    }
}

/// 저장하는 촬영 위치·방향 (EvidencePhoto의 positionX·positionY·positionZ·direction을 한 값으로 묶음)
nonisolated struct SavedPlacement: Hashable, Sendable {
    /// 도면 위 위치 (m)
    var position: SIMD2<Double>
    /// 바닥에서 높이 (m)
    var height: Double
    /// 촬영 방향 (도). 모르면 nil
    var direction: Double?

    init(position: SIMD2<Double>, height: Double, direction: Double?) {
        self.position = position
        self.height = height
        self.direction = direction
    }

    /// 도면 위 계산 결과를 저장하는 값으로
    init(_ placement: PhotoPlacement) {
        self.init(position: placement.position, height: placement.height, direction: placement.yaw)
    }
}

extension EvidencePhoto {
    /// 저장된 촬영 위치·방향. 위치(X·Y)가 없으면 nil
    var savedPlacement: SavedPlacement? {
        get {
            guard let positionX, let positionY else { return nil }
            return SavedPlacement(position: SIMD2(positionX, positionY), height: positionZ ?? 0, direction: direction)
        }
        set {
            positionX = newValue?.position.x
            positionY = newValue?.position.y
            positionZ = newValue?.height
            direction = newValue?.direction
        }
    }

    /// 저장된 카메라 자세. 없거나 못 읽으면 nil
    var cameraPose: ScanCameraPose? {
        cameraPoseData.flatMap { try? JSONDecoder().decode(ScanCameraPose.self, from: $0) }
    }

    /// 도면 위 촬영 위치·방향. 저장된 값을 먼저 쓰고, 없으면 카메라 자세로 계산한다
    func placement(in plan: PlanData) -> PhotoPlacement? {
        PhotoPlacement.resolved(saved: savedPlacement, pose: cameraPose, in: plan)
    }
}

extension PhotoPlacement {
    /// 저장된 위치·방향이 있으면 그것을 쓰고, 없으면 카메라 자세와 도면의 스캔 변환으로 계산한 값을 쓴다.
    /// 둘 다 없으면 nil. 저장된 값은 기울기·화각을 모르므로 카메라 자세가 있으면 거기서, 없으면 기본값을 쓴다
    static func resolved(saved: SavedPlacement?, pose: ScanCameraPose?, in plan: PlanData) -> PhotoPlacement? {
        guard let saved else {
            return pose.flatMap { plan.scanAlignment?.placement(of: $0) }
        }
        return PhotoPlacement(
            position: saved.position,
            yaw: saved.direction,
            pitch: pose?.pitch ?? 0,
            height: saved.height,
            fieldOfView: pose?.horizontalFieldOfView ?? defaultFieldOfView
        )
    }
}

/// 사진을 가져온 경로
enum PhotoSource: String, Codable {
    /// 앱 카메라로 찍음
    case camera
    /// 사진 앱에서 불러옴
    case photoLibrary
}

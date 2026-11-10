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
    /// 사용자가 놓거나 끌어 옮긴 도면 위 촬영 위치·방향 (ManualPlacement JSON). 없으면 nil. 읽고 쓸 때는 `manualPlacement`를 쓴다.
    /// 구조체를 SwiftData 칸으로 바로 두면 `SIMD2`가 있어 앱이 시작할 때 꺼져서 JSON으로 둔다
    var manualPlacementData: Data?

    init(
        id: UUID = UUID(),
        source: PhotoSource,
        isBookmarked: Bool = false,
        roomKey: String? = nil,
        takenAt: Date,
        imageData: Data,
        thumbnailData: Data,
        session: InvestigationSession? = nil,
        cameraPoseData: Data? = nil
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
    }
}

/// 사용자가 놓은 사진의 도면 위 촬영 위치·방향. 계산한 값이 아니라 입력 원본이라 정렬이 바뀌어도 그대로다
nonisolated struct ManualPlacement: Codable, Hashable, Sendable {
    /// 촬영 위치 (도면 좌표, m)
    var position: SIMD2<Double>
    /// 촬영 방향 (도). 도면 위쪽이 0°, 시계 방향. 모르면 nil
    var yaw: Double?
}

extension EvidencePhoto {
    /// 사용자가 놓은 촬영 위치·방향. 없거나 못 읽으면 nil
    var manualPlacement: ManualPlacement? {
        get { manualPlacementData.flatMap { try? JSONDecoder().decode(ManualPlacement.self, from: $0) } }
        set { manualPlacementData = newValue.flatMap { try? JSONEncoder().encode($0) } }
    }

    /// 저장된 카메라 자세. 없거나 못 읽으면 nil
    var cameraPose: ScanCameraPose? {
        cameraPoseData.flatMap { try? JSONDecoder().decode(ScanCameraPose.self, from: $0) }
    }

    /// 도면 위 촬영 위치·방향. 사용자가 놓은 위치를 먼저 쓰고, 없으면 카메라 자세로 계산한다
    func placement(in plan: PlanData) -> PhotoPlacement? {
        PhotoPlacement.resolved(manual: manualPlacement, pose: cameraPose, in: plan)
    }
}

extension PhotoPlacement {
    /// 도면 위 촬영 위치·방향을 정한다. 위치와 방향은 사용자가 놓은 값이 있으면 그것, 없으면 카메라 자세와 도면의 스캔 변환으로 계산한 값이다.
    /// 기울기·화각·높이는 카메라 자세에서만 나온다. 둘 다 없으면 nil
    static func resolved(manual: ManualPlacement?, pose: ScanCameraPose?, in plan: PlanData) -> PhotoPlacement? {
        let computed = pose.flatMap { plan.scanAlignment?.placement(of: $0) }
        guard let manual else { return computed }
        return PhotoPlacement(
            position: manual.position,
            yaw: manual.yaw ?? computed?.yaw,
            pitch: pose?.pitch,
            height: computed?.height,
            fieldOfView: pose?.horizontalFieldOfView
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

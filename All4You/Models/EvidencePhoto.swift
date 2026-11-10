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
    /// 도면 위 촬영 위치·방향·시야 (PhotoPlacement JSON). 위치를 모르는 사진은 nil. 읽고 쓸 때는 `placement`를 쓴다.
    /// 구조체를 SwiftData 칸으로 바로 두면 `SIMD2`가 있어 앱이 시작할 때 꺼져서 JSON으로 둔다
    var placementData: Data?

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
        placement: PhotoPlacement? = nil
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
        self.placementData = placement.flatMap { try? JSONEncoder().encode($0) }
    }
}

extension EvidencePhoto {
    /// 저장된 촬영 위치·방향·시야. 없거나 못 읽으면 nil
    var placement: PhotoPlacement? {
        get { placementData.flatMap { try? JSONDecoder().decode(PhotoPlacement.self, from: $0) } }
        set { placementData = newValue.flatMap { try? JSONEncoder().encode($0) } }
    }

    /// 저장된 카메라 자세. 없거나 못 읽으면 nil
    var cameraPose: ScanCameraPose? {
        cameraPoseData.flatMap { try? JSONDecoder().decode(ScanCameraPose.self, from: $0) }
    }

    /// 도면 위 촬영 위치·방향. 저장된 값을 먼저 쓰고, 없으면 카메라 자세로 계산한다
    func placement(in plan: PlanData) -> PhotoPlacement? {
        PhotoPlacement.resolved(saved: placement, pose: cameraPose, in: plan)
    }
}

extension PhotoPlacement {
    /// 저장된 값이 있으면 그것을 쓰고, 없으면 카메라 자세와 도면의 스캔 변환으로 계산한 값을 쓴다. 둘 다 없으면 nil
    static func resolved(saved: PhotoPlacement?, pose: ScanCameraPose?, in plan: PlanData) -> PhotoPlacement? {
        saved ?? pose.flatMap { plan.scanAlignment?.placement(of: $0) }
    }
}

/// 사진을 가져온 경로
enum PhotoSource: String, Codable {
    /// 앱 카메라로 찍음
    case camera
    /// 사진 앱에서 불러옴
    case photoLibrary
}

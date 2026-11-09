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

    init(
        id: UUID = UUID(),
        source: PhotoSource,
        isBookmarked: Bool = false,
        roomKey: String? = nil,
        takenAt: Date,
        imageData: Data,
        thumbnailData: Data,
        session: InvestigationSession? = nil
    ) {
        self.id = id
        self.source = source
        self.isBookmarked = isBookmarked
        self.roomKey = roomKey
        self.takenAt = takenAt
        self.imageData = imageData
        self.thumbnailData = thumbnailData
        self.session = session
    }
}

/// 사진을 가져온 경로
enum PhotoSource: String, Codable {
    /// 앱 카메라로 찍음
    case camera
    /// 사진 앱에서 불러옴
    case photoLibrary
}

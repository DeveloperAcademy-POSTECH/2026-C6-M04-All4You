// SwiftData에 저장하는 메모 모델. 메모 화면·도면 핀은 이것을 FloorPlanMemo로 바꿔 보여 준다

import Foundation
import SwiftData

/// 사건에 남긴 메모 하나. 도면 위 한 점에 붙고, 그 점이 든 장소(방)를 가리킨다
@Model
final class Memo {
    @Attribute(.unique) var id: UUID
    /// 목록에 보이는 제목 ("메모 #1")
    var title: String
    var content: String
    var createdAt: Date
    /// 메모가 가리키는 장소 (planData `rooms[].id`). nil이면 장소 밖 메모
    var targetKey: String?
    /// 메모를 쓸 때의 장소 이름. 장소가 지워졌거나 장소 밖 메모일 때 보인다 (장소가 있으면 지금 이름을 쓴다)
    var locationName: String
    /// 메모 핀이 놓인 도면 좌표 (m)
    var anchorX: Double
    var anchorY: Double
    /// 이 메모가 속한 사건. 반대쪽은 `FireCase.memos`
    var fireCase: FireCase?

    init(
        id: UUID = UUID(),
        title: String,
        content: String,
        createdAt: Date = .now,
        targetKey: String?,
        locationName: String,
        anchorX: Double,
        anchorY: Double
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.targetKey = targetKey
        self.locationName = locationName
        self.anchorX = anchorX
        self.anchorY = anchorY
    }
}

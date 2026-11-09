// SwiftData에 저장하는 평면도 모델. 도면 내용은 planData에 JSON 하나로 담는다

import Foundation
import SwiftData

/// 사건 하나에 하나씩 있는 평면도
@Model
final class FloorPlan {
    /// 도면을 만든 방식 (공간 스캔, 직접 그리기, 외부 도면 가져오기)
    var sourceType: FloorPlanSourceType
    /// 2D·3D가 함께 보는 도면(`PlanData`)을 JSON으로 바꾼 값. 읽고 쓰기는 `loadPlanData()`·`storePlanData(_:)`
    var planData: Data
    /// RoomPlan 스캔 원본(JSON). 공간 스캔으로 만든 평면도만 있다. 현장은 다시 스캔할 수 없으므로, 변환 규칙을 고친 뒤 다시 변환할 때 쓴다.
    /// 읽기는 `loadRoomPlan()`
    @Attribute(.externalStorage) var roomPlanData: Data?
    /// 이 평면도가 속한 사건. 반대쪽은 `FireCase.floorPlan`
    var fireCase: FireCase?

    init(sourceType: FloorPlanSourceType, planData: Data, roomPlanData: Data? = nil, fireCase: FireCase? = nil) {
        self.sourceType = sourceType
        self.planData = planData
        self.roomPlanData = roomPlanData
        self.fireCase = fireCase
    }
}

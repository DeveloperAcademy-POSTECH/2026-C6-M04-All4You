// 변환이 끝난 도면을 사건의 평면도로 저장하는 규칙

import Foundation

extension FireCase {
    /// 새로 만든 도면을 사건의 평면도로 저장한다. 이미 있으면 만든 방식과 내용을 바꾼다.
    /// roomPlanData: 공간 스캔 원본. 다른 방식으로 다시 만들면 nil로 지운다
    func replaceFloorPlan(with plan: PlanData, sourceType: FloorPlanSourceType, roomPlanData: Data? = nil) throws {
        if let floorPlan {
            floorPlan.sourceType = sourceType
            floorPlan.roomPlanData = roomPlanData
            try floorPlan.storePlanData(plan)
        } else {
            floorPlan = try FloorPlan(sourceType: sourceType, plan: plan, roomPlanData: roomPlanData)
        }
    }
}

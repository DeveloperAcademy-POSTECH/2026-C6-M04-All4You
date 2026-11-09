// 평면도에 저장된 JSON(planData)을 도면 값(PlanData)으로 읽고 쓰기

import Foundation

// SwiftData 모델(@Model)은 메인 전용이 아니어서, 메인 전용인 PlanData를 쓰려면 메인에서만 부른다고 표시한다.
// 부르는 곳은 모두 화면이라 지금도 메인에서 돈다
@MainActor
extension FloorPlan {
    /// 도면 값으로 평면도를 만든다
    convenience init(sourceType: FloorPlanSourceType, plan: PlanData, roomPlanData: Data? = nil, fireCase: FireCase? = nil) throws {
        self.init(sourceType: sourceType, planData: try JSONEncoder().encode(plan), roomPlanData: roomPlanData, fireCase: fireCase)
    }

    /// 저장된 JSON을 도면 값으로 읽는다. 형식이 맞지 않으면 nil
    func loadPlanData() -> PlanData? {
        try? JSONDecoder().decode(PlanData.self, from: planData)
    }

    /// 도면 값을 JSON으로 바꿔 덮어쓴다
    func storePlanData(_ plan: PlanData) throws {
        planData = try JSONEncoder().encode(plan)
    }
}

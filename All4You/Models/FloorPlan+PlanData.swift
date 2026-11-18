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

    /// 저장된 JSON을 도면 값으로 읽는다. 옛 형식(version 1)은 지금 형식으로 바꿔 읽는다. 형식이 맞지 않거나 더 새 버전이면 nil
    func loadPlanData() -> PlanData? {
        guard var plan = PlanData.decodeStored(planData) else { return nil }
        if sourceType == .iPadDrawing,
           let index = plan.doorWindows.firstIndex(where: {
               $0.id == "balconyPassage" && $0.wallId == "balconyDivider" && $0.kind == .window
           }), plan.vertices.contains(where: { $0.id == "middleBalcony" }) {
            plan.doorWindows[index].kind = .door
            plan.doorWindows[index].doorStyle = .sliding
            plan.doorWindows[index].sillHeight = 0
            plan.doorWindows[index].height = 2.0
        }
        return plan
    }

    /// 도면 값을 JSON으로 바꿔 덮어쓴다. 저장돼 있던 JSON이 옛 형식(version 1)이면 바꾸기 전 원본을 파일로 한 번 남긴다
    /// (읽기만 하고 저장하지 않은 도면은 그대로 version 1이라, 처음 덮어쓰는 이때 한 번만 남는다)
    func storePlanData(_ plan: PlanData) throws {
        let data = try JSONEncoder().encode(plan)
        if PlanData.storedVersion(of: planData) == 1 {
            AppStore.keepPlanBeforeMigration(planData, caseID: fireCase?.id)
        }
        planData = data
    }
}

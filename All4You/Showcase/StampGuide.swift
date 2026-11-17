// 쇼케이스용: 도면 수정에서 피해자 → 전기 → 발화지점 순서로 다음에 놓을 스탬프 도구를 정한다

extension PlanData {
    /// 아직 놓지 않은 첫 스탬프 도구. 셋 다 놓였으면 nil
    var nextGuidedStampTool: EditTool? {
        if !markers.contains(where: { $0.kind == .person }) { return .person }
        // 전기는 바닥(PlanMarker)과 벽(WallFixture) 어느 쪽이든 하나면 된다
        if !markers.contains(where: { $0.kind == .outlet }), !wallFixtures.contains(where: { $0.kind == .outlet }) { return .outlet }
        if !markers.contains(where: { $0.kind == .ignitionPoint }) { return .ignitionPoint }
        return nil
    }
}

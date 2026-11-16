// 도면으로 쓸 수 있는지 보는 검사

extension PlanData {
    /// 도면으로 쓸 수 있으면 true. 벽·바닥·가구 가운데 하나라도 있으면 쓸 수 있다 (벽이 없어도 바닥·가구·라벨이 보이고 수정할 수 있다).
    /// 평면도는 변환이 끝날 때 만들고 "평면도가 있으면 항상 내용이 있다"는 결정을 지키려고, 저장하거나 열기 전에 이 값을 본다
    var isUsable: Bool { !walls.isEmpty || !(floors ?? []).isEmpty || !(furniture ?? []).isEmpty }
}

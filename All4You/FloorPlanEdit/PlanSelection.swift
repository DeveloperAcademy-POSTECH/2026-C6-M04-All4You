// 수정 화면에서 고른 도면 요소 하나. 화면 상태라 저장하지 않는다
// 케이스 이름은 PlanData의 칸(markers·wallFixtures·doorWindows)을 따르고, 값은 그 요소의 id

enum PlanSelection: Equatable {
    /// 사람·발화지점 (PlanMarker.id)
    case marker(String)
    /// 콘센트 (WallFixture.id)
    case wallFixture(String)
    /// 창문 (DoorWindow.id). 문·개구부는 고르지 않는다
    case doorWindow(String)
}

// 수정 화면에서 고른 도면 요소 하나. 화면 상태라 저장하지 않는다
// 케이스 이름은 PlanData의 칸(markers·wallFixtures·doorWindows·furniture)을 따르고, 값은 그 요소의 id

enum PlanSelection: Equatable {
    /// 사람·발화지점 (PlanMarker.id)
    case marker(String)
    /// 콘센트 (WallFixture.id)
    case wallFixture(String)
    /// 창문·문 (DoorWindow.id). 문짝 없는 개구부는 고르지 않는다
    case doorWindow(String)
    /// 벽 한 줄 (Wall.id). 2D에서 손 도구로만 고른다
    case wall(String)
    /// 가구 (Furniture.id). 2D에서 도구를 고르지 않았을 때만 고른다
    case furniture(String)
}

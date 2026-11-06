// 벽에 달린 문·창문·개구부 (ERD v16 planData.doorWindows)

/// 벽을 따라간 중심 위치로 저장해서, 벽을 옮기면 함께 움직인다
struct DoorWindow: Codable, Equatable, Identifiable {
    let id: String
    /// 달린 벽 id (Wall.id)
    var wallId: String
    var kind: DoorWindowKind
    /// 벽 시작점에서 중심까지 (m)
    var centerAlongWall: Double
    /// 폭 (m)
    var width: Double
    /// 바닥에서 아래 끝까지 (m). 문은 0
    var sillHeight: Double
    /// 높이 (m)
    var height: Double
}

/// 문·창문 종류 (ERD v16 DoorWindowKind)
enum DoorWindowKind: String, Codable {
    /// 문
    case door
    /// 창문
    case window
    /// 문짝 없이 뚫린 출입구
    case passage
}

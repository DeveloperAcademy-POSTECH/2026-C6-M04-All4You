// 벽에 달린 문·창문·개구부

/// 벽을 따라간 중심 위치로 저장해서, 벽을 옮기면 함께 움직인다
struct DoorWindow: Codable, Hashable, Identifiable {
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

/// 문·창문 종류
enum DoorWindowKind: String, Codable {
    /// 문
    case door
    /// 창문
    case window
    /// 문짝 없이 뚫린 출입구(추후 고려 안한다면 삭제 가능성 존재)
    case passage
}

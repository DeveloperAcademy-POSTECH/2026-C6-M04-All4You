// 벽 한쪽 면에 붙은 것 planData.wallFixtures. 지금은 콘센트뿐

/// 벽을 따라간 위치와 바닥에서 높이로 저장해서, 벽을 옮기면 따라가고 3D에서 벽 면에 붙어 보인다
struct WallFixture: Codable, Hashable, Identifiable {
    let id: String
    /// 붙은 벽 id (Wall.id)
    var wallId: String
    var kind: FixtureKind
    /// 벽의 어느 면에 붙었는지
    var face: WallFace
    /// 벽 시작점에서 거리 (m)
    var positionAlongWall: Double
    /// 바닥에서 높이 (m)
    var heightFromFloor: Double
}

/// 벽에 붙는 것의 종류  FixtureKind
enum FixtureKind: String, Codable {
    /// 콘센트 (화면 글자 "전기")
    case outlet
}

/// 벽의 면. 벽 시작 → 끝 방향을 바라볼 때 왼쪽·오른쪽
enum WallFace: String, Codable {
    case left
    case right
}

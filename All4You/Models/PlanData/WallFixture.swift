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
    /// 전기 종류 (이 칸이 생기기 전에 저장한 도면도 그대로 읽히게 옵셔널)
    var electricalKind: ElectricalKind? = nil
    /// 종류가 기타(other)일 때 사용자가 적은 라벨 글자. 없으면 "기타"로 보인다 (이 칸이 생기기 전에 저장한 도면도 그대로 읽히게 옵셔널)
    var kindNote: String? = nil

    /// 종류가 기타라 라벨 글자를 직접 적을 수 있는지
    var isKindOther: Bool { electricalKind == .other }

    /// 스탬프 아래에 보일 종류 글자. 종류를 고르지 않은 것(예전에 저장한 도면)은 nil.
    /// 종류가 기타이고 적은 글자(kindNote)가 있으면 그 글자
    var kindLabel: String? {
        if isKindOther, let kindNote { return kindNote }
        return electricalKind?.title
    }
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

// 도면 위에 놓는 사람·발화지점 표시 planData.markers 스탬프. 벽에 붙는 콘센트와 성격이 달라 둘이 묶어 분리.

/// 바닥 위 위치·높이와 바라보는 방향을 가진 표시. 2D에서는 기호, 3D에서는 모델로 그린다
struct PlanMarker: Codable, Equatable, Identifiable {
    let id: String
    var kind: MarkerKind
    /// 도면 좌표 (x, y) (m). JSON에는 [x, y] 배열로 저장된다
    var position: SIMD2<Double>
    /// 바닥에서 높이 (m)
    var height: Double
    /// 바라보는 방향 (도). 도면 위쪽이 0°, 시계 방향으로 커진다
    var yaw: Double
    /// 누운 자세 (사람만, 나머지는 nil)
    var lying: Bool?
}

/// 표시 종류
enum MarkerKind: String, Codable {
    /// 사람 (화면 글자 "피해자")
    case person
    /// 발화지점
    case ignitionPoint
}

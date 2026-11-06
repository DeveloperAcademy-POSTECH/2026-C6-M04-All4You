// 벽 끝이 모이는 점 planData.vertices

/// 여러 벽이 함께 쓰는 꼭짓점. 꼭짓점을 옮기면 여기 붙은 벽이 함께 늘고 준다
struct Vertex: Codable, Equatable, Identifiable {
    let id: String
    /// 도면 좌표 (m)
    var x: Double
    var y: Double
}

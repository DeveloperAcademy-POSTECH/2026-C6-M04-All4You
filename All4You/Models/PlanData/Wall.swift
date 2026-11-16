// 벽 한 줄 planData.walls

/// 두 꼭짓점을 잇는 벽. 길이·방향은 저장하지 않고 꼭짓점 좌표로 계산한다
struct Wall: Codable, Hashable, Identifiable {
    let id: String
    /// 시작·끝 꼭짓점 id (Vertex.id)
    var startVertex: String
    var endVertex: String
    /// 두께·높이 (m)
    var thickness: Double
    var height: Double
}

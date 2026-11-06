// 벽 한 줄 (ERD v16 planData.walls)

/// 두 꼭짓점을 잇는 벽. 길이·방향은 저장하지 않고 꼭짓점 좌표로 계산한다
struct Wall: Codable, Equatable, Identifiable {
    let id: String
    /// 시작·끝 꼭짓점 id (Vertex.id)
    var startVertex: String
    var endVertex: String
    /// 두께·높이 (m)
    var thickness: Double
    var height: Double
    /// 방을 닫으려고 넣은 가상 경계선. 2D·3D에 벽으로 그리지 않는다
    var isVirtual: Bool
}

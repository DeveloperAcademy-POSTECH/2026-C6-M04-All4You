// 장소(방) 하나

/// 이름과, 방을 한 바퀴 도는 벽 목록. id는 사진(EvidencePhoto.roomKey)·메모가 가리키므로 편집해도 바꾸지 않는다
struct Room: Codable, Hashable, Identifiable {
    let id: String
    /// 장소명 (거실, 안방 등)
    var name: String
    /// 방을 한 바퀴 도는 경계 벽들
    var boundary: [RoomEdge]
    /// 이름을 보여 줄 도면 좌표 (m)
    var labelX: Double
    var labelY: Double
}

/// 방 경계의 벽 하나
struct RoomEdge: Codable, Hashable {
    /// 경계 벽 id (Wall.id)
    var wallId: String
    /// true면 벽 시작 → 끝 방향으로 돈다
    var forward: Bool
}

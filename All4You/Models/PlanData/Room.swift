// 공간 라벨 하나

/// 이름과 이름을 보여 줄 자리(점). 영역(벽으로 닫힌 칸·스캔한 바닥)은 저장하지 않고 이 자리에서 그때그때 계산한다 (PlanRegions).
/// id는 사진(EvidencePhoto.roomKey)·메모가 가리키므로 편집해도 바꾸지 않는다
struct Room: Codable, Hashable, Identifiable {
    let id: String
    /// 장소명 (거실, 안방 등)
    var name: String
    /// 이름을 보여 줄 도면 좌표 (m)
    var labelX: Double
    var labelY: Double
}

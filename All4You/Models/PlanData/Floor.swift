// 스캔한 바닥 하나. 벽과 별개로 저장해, 벽을 고치거나 없어도 바닥은 그대로 남는다

/// 스캔한 바닥 하나. 꼭짓점을 벽과 함께 쓰지 않아, 벽을 고쳐도 바닥은 그대로다
// TEMP: ERD에 없는 값 — ERD 반영 때 이름·자리가 바뀔 수 있음
struct Floor: Codable, Hashable, Identifiable {
    let id: String
    /// 바닥 둘레를 돌아가는 순서의 꼭짓점. 3개 이상
    var corners: [FloorCorner]
}

/// 바닥 꼭짓점 하나. 도면 좌표 (m)
// TEMP: ERD에 없는 값 — ERD 반영 때 이름·자리가 바뀔 수 있음
struct FloorCorner: Codable, Hashable {
    var x: Double
    var y: Double
}

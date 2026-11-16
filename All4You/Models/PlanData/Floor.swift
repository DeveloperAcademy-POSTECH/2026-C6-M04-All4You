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

extension Floor {
    /// 꼭짓점을 돌아가는 순서의 도면 점들
    var points: [SIMD2<Double>] { corners.map { SIMD2($0.x, $0.y) } }

    /// 점 point에서 가장 가까운 바닥 테두리 위의 점과 그 거리 (m)
    func nearestEdgePoint(to point: SIMD2<Double>) -> (point: SIMD2<Double>, distance: Double)? {
        let points = self.points
        var best: (point: SIMD2<Double>, distance: Double)?
        for index in points.indices {
            let edge = WallLine(start: points[index], end: points[(index + 1) % points.count])
            let along = min(max(((point - edge.start) * edge.direction).sum(), 0), edge.length)
            let onEdge = edge.point(along: along)
            let delta = point - onEdge
            let distance = (delta * delta).sum().squareRoot()
            if distance < best?.distance ?? .infinity { best = (onEdge, distance) }
        }
        return best
    }
}

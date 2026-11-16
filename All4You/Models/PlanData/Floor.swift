// 스캔한 바닥 하나. 벽과 별개로 저장해, 벽을 고치거나 없어도 바닥은 그대로 남는다

// TEMP: Floor·FloorCorner는 ERD에 없는 값이라 PlanData에 먼저 둠 — ERD 반영 때 이름·자리가 바뀔 수 있음

/// 스캔한 바닥 하나. 꼭짓점을 벽과 함께 쓰지 않아, 벽을 고쳐도 바닥은 그대로다
struct Floor: Codable, Hashable, Identifiable {
    let id: String
    /// 바닥 둘레를 돌아가는 순서의 꼭짓점. 3개 이상
    var corners: [FloorCorner]
}

/// 바닥 꼭짓점 하나. 도면 좌표 (m)
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

    /// 바닥을 삼각형으로 나눈 결과. 3D는 삼각형으로만 면을 그릴 수 있어서 필요하다. 세 개씩 한 삼각형이고, 값은 corners의 번호다.
    /// 귀 자르기(ear clipping)로 나눠서 ㄱ자·ㄷ자 같은 오목한 모양도 맞게 나뉜다.
    /// 귀 자르기: 볼록한 꼭짓점 하나와 이웃한 두 꼭짓점으로 삼각형을 만들었을 때 그 안에 다른 꼭짓점이 없으면 그 삼각형을 떼어 내고, 남은 모양에 같은 일을 되풀이한다.
    /// 꼭짓점이 3개 미만이거나 넓이가 없으면 빈 배열이다. 모양이 스스로 겹쳐 귀를 못 찾으면 남은 꼭짓점을 부채꼴로 잇는다
    var triangleIndices: [UInt32] {
        let points = self.points
        guard points.count >= 3, abs(PlanData.signedArea(points)) > WallMoveRules.eps else { return [] }
        // 돌아가는 방향을 맞춘다 (넓이가 +이면 그대로, −이면 뒤집는다)
        var remaining = Array(points.indices)
        if PlanData.signedArea(points) < 0 { remaining.reverse() }
        func cross(_ o: SIMD2<Double>, _ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
            (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
        }
        func isInside(_ p: SIMD2<Double>, _ a: SIMD2<Double>, _ b: SIMD2<Double>, _ c: SIMD2<Double>) -> Bool {
            let eps = WallMoveRules.eps
            // 삼각형 변 위에 놓인 꼭짓점도 막는 것으로 본다 (오목한 꼭짓점이 대각선 위에 있으면 그 귀를 자르면 안 된다)
            return cross(a, b, p) >= -eps && cross(b, c, p) >= -eps && cross(c, a, p) >= -eps
        }
        var triangles: [UInt32] = []
        var attempts = 0
        while remaining.count > 3, attempts < points.count * points.count {
            attempts += 1
            var isClipped = false
            for position in remaining.indices {
                let previous = remaining[(position + remaining.count - 1) % remaining.count]
                let current = remaining[position]
                let next = remaining[(position + 1) % remaining.count]
                // 볼록한 꼭짓점이고 그 삼각형 안에 다른 꼭짓점이 없으면 귀다
                guard cross(points[previous], points[current], points[next]) > WallMoveRules.eps else { continue }
                let hasOtherInside = remaining.contains { other in
                    other != previous && other != current && other != next
                        && isInside(points[other], points[previous], points[current], points[next])
                }
                guard !hasOtherInside else { continue }
                triangles += [UInt32(previous), UInt32(current), UInt32(next)]
                remaining.remove(at: position)
                isClipped = true
                break
            }
            if !isClipped { break }
        }
        if remaining.count >= 3 {
            for position in 1..<(remaining.count - 1) {
                triangles += [UInt32(remaining[0]), UInt32(remaining[position]), UInt32(remaining[position + 1])]
            }
        }
        return triangles
    }
}

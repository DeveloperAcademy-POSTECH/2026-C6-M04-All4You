// 스캔한 바닥 하나. 벽과 별개로 저장해, 벽을 고치거나 없어도 바닥은 그대로 남는다

import Foundation
import simd

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

    /// 바닥을 한 번에 키우거나 줄일 때 가로·세로가 이보다(m) 작아지지 않게 한다
    // TEMP: 가장 작은 크기는 임시로 정함
    static let minimumSize = 0.5

    /// 모든 꼭짓점을 감싸는 사각형의 왼쪽 위(min)와 오른쪽 아래(max). 크기 조절 손잡이를 이 사각형의 네 모서리에 둔다
    var bounds: (min: SIMD2<Double>, max: SIMD2<Double>)? {
        let points = self.points
        guard let first = points.first else { return nil }
        return points.reduce((min: first, max: first)) { (min: simd_min($0.min, $1), max: simd_max($0.max, $1)) }
    }

    /// 감싸는 사각형의 모서리. 0 왼쪽 위, 1 오른쪽 위, 2 오른쪽 아래, 3 왼쪽 아래
    func boundsCorner(_ index: Int) -> SIMD2<Double>? {
        guard let bounds else { return nil }
        switch index {
        case 0: return bounds.min
        case 1: return SIMD2(bounds.max.x, bounds.min.y)
        case 2: return bounds.max
        case 3: return SIMD2(bounds.min.x, bounds.max.y)
        default: return nil
        }
    }

    /// 다각형을 바깥으로 margin(m)만큼 넓힌 꼭짓점들. 꼭짓점마다 이어진 두 변의 바깥쪽 방향을 합쳐 밀어서, 모든 변이 같은 간격으로 떨어진다.
    /// 아주 뾰족한 꼭짓점이 너무 멀리 밀리지 않게 미는 거리는 margin의 2배까지만 한다
    static func expanded(_ polygon: [SIMD2<Double>], by margin: Double) -> [SIMD2<Double>] {
        let area = PlanData.signedArea(polygon)
        guard polygon.count >= 3, abs(area) > WallMoveRules.eps else { return polygon }
        // 변의 바깥쪽 방향. 넓이가 +이면 변 방향의 오른쪽, −이면 왼쪽이다
        func outward(from a: SIMD2<Double>, to b: SIMD2<Double>) -> SIMD2<Double>? {
            let delta = b - a
            let length = (delta * delta).sum().squareRoot()
            guard length > WallMoveRules.eps else { return nil }
            let direction = delta / length
            return area > 0 ? SIMD2(direction.y, -direction.x) : SIMD2(-direction.y, direction.x)
        }
        return polygon.indices.map { index in
            let previous = polygon[(index + polygon.count - 1) % polygon.count]
            let current = polygon[index]
            let next = polygon[(index + 1) % polygon.count]
            guard let incoming = outward(from: previous, to: current), let outgoing = outward(from: current, to: next) else { return current }
            var push = (incoming + outgoing) / (1 + (incoming * outgoing).sum())
            let length = (push * push).sum().squareRoot()
            if length > 2 { push = push / length * 2 }
            return current + push * margin
        }
    }
}


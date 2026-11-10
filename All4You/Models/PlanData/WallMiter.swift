// 벽 끝을 이웃 벽에 맞춰 비스듬히 자르는 계산 (3D 벽 모양용).
// 상자 벽은 끝을 두께 절반만큼 늘려 모서리를 메웠는데, 벽이 대각선이면 늘린 끝이 이웃 벽 밖으로 튀어나온다.
// 그래서 벽마다 양 끝의 왼쪽·오른쪽 가장자리가 어디까지 가는지(벽을 따라간 거리) 따로 구해, 끝 모양을 이웃 벽 면에 딱 맞게 자른다

import Foundation

/// 벽 하나의 양 끝 모양. 값은 벽 시작점에서 벽을 따라간 거리 (m)이고, 0보다 작거나 벽 길이보다 크면 그 끝에서 벽 밖으로 늘어난 것이다.
/// 왼쪽·오른쪽은 시작 → 끝 방향을 바라볼 때의 가장자리 (WallFace.left·right와 같다)
struct WallMiter {
    var startLeft: Double
    var startRight: Double
    var endLeft: Double
    var endRight: Double

    /// 끝을 자르지 않은(수직으로 자른) 모양
    static func square(length: Double) -> WallMiter {
        WallMiter(startLeft: 0, startRight: 0, endLeft: length, endRight: length)
    }
}

extension PlanData {
    /// 벽 하나의 양 끝 모양. 그리는 벽(가상 경계선이 아닌 벽)끼리만 이웃으로 본다
    func wallMiter(of wall: Wall) -> WallMiter {
        guard let line = line(of: wall), line.length > WallMiterRule.eps else { return .square(length: 0) }
        let points = vertexPoints
        let start = junction(at: wall.startVertex, of: wall, outward: line.direction, points: points)
        let end = junction(at: wall.endVertex, of: wall, outward: -line.direction, points: points)
        // 시작 끝에서는 minus가 벽의 왼쪽, plus가 오른쪽 가장자리다. 끝 쪽은 바깥 방향이 반대라 왼쪽·오른쪽이 뒤바뀌고, 벽 길이에서 빼서 시작점 기준 거리로 바꾼다
        return WallMiter(
            startLeft: start.minus,
            startRight: start.plus,
            endLeft: line.length - end.plus,
            endRight: line.length - end.minus
        )
    }

    /// 꼭짓점 vertexId에서 wall이 이웃 벽과 만나는 모양. outward는 그 꼭짓점에서 wall을 따라 나가는 방향.
    /// plus는 반시계 쪽 가장자리, minus는 시계 쪽 가장자리가 꼭짓점에서 outward 방향으로 얼마나 떨어진 곳에서 끝나는지 (음수면 꼭짓점 너머로 늘어남)
    private func junction(at vertexId: String, of wall: Wall, outward: SIMD2<Double>, points: [String: SIMD2<Double>]) -> (plus: Double, minus: Double) {
        guard let origin = points[vertexId] else { return (0, 0) }
        let eps = WallMiterRule.eps
        var arms: [(id: String, direction: SIMD2<Double>, thickness: Double)] = [(wall.id, outward, wall.thickness)]
        for other in walls where !other.isVirtual && other.id != wall.id {
            let farId: String
            if other.startVertex == vertexId { farId = other.endVertex } else if other.endVertex == vertexId { farId = other.startVertex } else { continue }
            guard let far = points[farId] else { continue }
            let vector = far - origin
            let length = (vector * vector).sum().squareRoot()
            guard length > eps else { continue }
            arms.append((other.id, vector / length, other.thickness))
        }
        guard arms.count > 1 else { return (0, 0) }

        // 이 벽과 정반대로 뻗은 벽이 있으면 이 벽은 곧게 이어지는 벽이다. 끝을 자르지 않고 가로로 맞닿게 둔다
        // (옆에서 붙는 벽이 곧은 벽의 면까지 와서 멈추므로 빈틈이 없다)
        if arms.dropFirst().contains(where: { abs(Self.cross(outward, $0.direction)) < WallMiterRule.parallelTolerance && (outward * $0.direction).sum() < 0 }) {
            return (0, 0)
        }

        let sorted = arms.sorted { atan2($0.direction.y, $0.direction.x) < atan2($1.direction.y, $1.direction.x) }
        guard let index = sorted.firstIndex(where: { $0.id == wall.id }) else { return (0, 0) }
        let next = sorted[(index + 1) % sorted.count]
        let previous = sorted[(index + sorted.count - 1) % sorted.count]
        let me = sorted[index]

        func limited(_ value: Double, _ other: Double) -> Double {
            let limit = WallMiterRule.miterLimit * max(me.thickness, other)
            return min(max(value, -limit), limit)
        }
        // 반시계 쪽 가장자리: 이 벽의 + 가장자리와 다음 벽의 - 가장자리가 만나는 점
        var plus = 0.0
        let crossNext = Self.cross(me.direction, next.direction)
        if abs(crossNext) > WallMiterRule.parallelTolerance {
            plus = limited((next.thickness / 2 + (me.thickness / 2) * (me.direction * next.direction).sum()) / crossNext, next.thickness)
        }
        // 시계 쪽 가장자리: 앞 벽의 + 가장자리와 이 벽의 - 가장자리가 만나는 점
        var minus = 0.0
        let crossPrevious = Self.cross(me.direction, previous.direction)
        if abs(crossPrevious) > WallMiterRule.parallelTolerance {
            minus = limited((-previous.thickness / 2 - (me.thickness / 2) * (me.direction * previous.direction).sum()) / crossPrevious, previous.thickness)
        }
        return (plus, minus)
    }

    private static func cross(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
        a.x * b.y - a.y * b.x
    }
}

private enum WallMiterRule {
    static let eps = 1e-6
    /// 두 방향의 외적이 이보다 작으면 나란한 것으로 본다 (약 0.06°)
    static let parallelTolerance = 1e-3
    /// 아주 뾰족한 모서리에서 끝이 길게 뻗지 않도록, 늘어나는 길이를 벽 두께의 이 배수로 제한한다
    static let miterLimit = 3.0
}

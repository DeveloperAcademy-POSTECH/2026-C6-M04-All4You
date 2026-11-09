// 도면 점·스탬프가 방 안쪽인지 보는 계산. 스탬프가 벽 바깥이나 도면 밖에 놓이거나 벽을 뚫지 않게 할 때 쓴다

import Foundation

extension PlanData {
    /// 사람·발화지점이 바닥에서 차지하는 자리(footprint) 전체가 방 안이고 어느 벽에도 닿지 않는지
    func fits(_ marker: PlanMarker) -> Bool {
        let footprint = marker.footprint
        guard isInsideRoom(footprint.start), isInsideRoom(footprint.end) else { return false }
        return !walls.contains { wall in
            guard !wall.isVirtual, let line = line(of: wall) else { return false }
            let gap = Self.distance(between: (footprint.start, footprint.end), and: (line.start, line.end))
            return gap < wall.thickness / 2 + footprint.radius
        }
    }

    /// 점 p(도면 좌표, m)가 어느 방 안이고, 벽 두께 위가 아닌지
    func isInsideRoom(_ p: SIMD2<Double>) -> Bool {
        guard rooms.contains(where: { Self.polygon(polygon(of: $0), contains: p) }) else { return false }
        return !walls.contains { wall in
            guard !wall.isVirtual, let line = line(of: wall) else { return false }
            return line.distance(to: p) < wall.thickness / 2
        }
    }

    /// 점 p(도면 좌표, m)를 품은 방. 어느 방에도 없으면 nil
    func room(containing p: SIMD2<Double>) -> Room? {
        rooms.first { Self.polygon(polygon(of: $0), contains: p) }
    }

    /// 방을 한 바퀴 도는 꼭짓점 점들 (도면 좌표). 경계 벽의 도는 방향 쪽 시작점을 차례로 모은다
    func polygon(of room: Room) -> [SIMD2<Double>] {
        room.boundary.compactMap { edge in
            guard let wall = wall(id: edge.wallId), let line = line(of: wall) else { return nil }
            return edge.forward ? line.start : line.end
        }
    }

    /// 다각형 안에 점이 있는지. 점에서 오른쪽으로 그은 선이 변을 홀수 번 지나면 안이다
    static func polygon(_ points: [SIMD2<Double>], contains p: SIMD2<Double>) -> Bool {
        guard points.count >= 3 else { return false }
        var isInside = false
        var previous = points[points.count - 1]
        for current in points {
            let crossesRow = (current.y > p.y) != (previous.y > p.y)
            if crossesRow {
                let crossX = current.x + (p.y - current.y) / (previous.y - current.y) * (previous.x - current.x)
                if p.x < crossX { isInside.toggle() }
            }
            previous = current
        }
        return isInside
    }

    /// 두 선분 사이 가장 짧은 거리 (m). 서로 가로지르면 0
    private static func distance(
        between a: (SIMD2<Double>, SIMD2<Double>),
        and b: (SIMD2<Double>, SIMD2<Double>)
    ) -> Double {
        func cross(_ o: SIMD2<Double>, _ p: SIMD2<Double>, _ q: SIMD2<Double>) -> Double {
            (p.x - o.x) * (q.y - o.y) - (p.y - o.y) * (q.x - o.x)
        }
        let crossesB = (cross(b.0, b.1, a.0) > 0) != (cross(b.0, b.1, a.1) > 0)
        let crossesA = (cross(a.0, a.1, b.0) > 0) != (cross(a.0, a.1, b.1) > 0)
        if crossesA && crossesB { return 0 }
        let lineA = WallLine(start: a.0, end: a.1)
        let lineB = WallLine(start: b.0, end: b.1)
        return min(lineA.distance(to: b.0), lineA.distance(to: b.1), lineB.distance(to: a.0), lineB.distance(to: a.1))
    }
}

// 스탬프가 바닥에서 차지하는 자리
extension PlanMarker {
    /// 3D 모델 크기(m)를 위에서 본 자리. 가운데 선분(start → end)과, 그 선분에서 바깥 가장자리까지(radius).
    /// 누운 사람은 발끝 → 머리끝 선분, 선 사람·발화지점은 점(원). 크기 배율을 곱한다
    var footprint: (start: SIMD2<Double>, end: SIMD2<Double>, radius: Double) {
        let size = drawScale
        guard kind == .person, lying == true else {
            return (position, position, Footprint.uprightRadius * size)
        }
        // 머리가 향하는 방향. yaw는 도면 위쪽 0°에서 시계 방향, 도면은 +y가 아래
        let radians = yaw * .pi / 180
        let headward = SIMD2(sin(radians), -cos(radians))
        return (
            position - headward * (Footprint.lyingToFeet * size),
            position + headward * (Footprint.lyingToHead * size),
            Footprint.lyingHalfWidth * size
        )
    }

    /// 3D 모델(FloorPlan3DBuilder)의 크기 (m). 모델을 바꾸면 함께 바꾼다
    private enum Footprint {
        /// 누운 사람: 표시 위치(몸통 가운데)에서 발끝까지, 머리끝까지, 몸 폭의 절반
        static let lyingToFeet = 0.6
        static let lyingToHead = 0.88
        static let lyingHalfWidth = 0.2
        /// 선 사람·발화지점이 바닥에서 차지하는 원의 반지름
        static let uprightRadius = 0.2
    }
}

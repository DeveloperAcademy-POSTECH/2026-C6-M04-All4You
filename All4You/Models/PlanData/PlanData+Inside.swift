// 도면 점이 방 안쪽인지 보는 계산. 스탬프가 벽 바깥이나 도면 밖에 놓이지 않게 할 때 쓴다

extension PlanData {
    /// 점 p(도면 좌표, m)가 어느 방 안이고, 벽 두께 위가 아닌지
    func isInsideRoom(_ p: SIMD2<Double>) -> Bool {
        guard rooms.contains(where: { Self.polygon(polygon(of: $0), contains: p) }) else { return false }
        return !walls.contains { wall in
            guard !wall.isVirtual, let line = line(of: wall) else { return false }
            return line.distance(to: p) < wall.thickness / 2
        }
    }

    /// 방을 한 바퀴 도는 꼭짓점 점들 (도면 좌표). 경계 벽의 도는 방향 쪽 시작점을 차례로 모은다
    func polygon(of room: Room) -> [SIMD2<Double>] {
        room.boundary.compactMap { edge in
            guard let wall = wall(id: edge.wallId), let line = line(of: wall) else { return nil }
            return edge.forward ? line.start : line.end
        }
    }

    /// 다각형 안에 점이 있는지. 점에서 오른쪽으로 그은 선이 변을 홀수 번 지나면 안이다
    private static func polygon(_ points: [SIMD2<Double>], contains p: SIMD2<Double>) -> Bool {
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
}

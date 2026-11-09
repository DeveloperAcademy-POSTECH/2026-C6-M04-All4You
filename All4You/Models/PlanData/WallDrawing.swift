// 펜으로 새 벽을 그리고 지우개로 벽을 지우는 계산
//
// 그리기: 끈 방향으로 직선을 양쪽으로 늘여, 양 끝을 처음 부딪히는 벽에 붙인 벽 한 줄. 부딪힌 자리가 꼭짓점 가까이면 꼭짓점에,
// 아니면 그 벽을 둘로 나눠 붙인다. 거의 가로·세로면 가로·세로로 맞춘다. 새 벽이 방을 닫으면 방을 나눈다.
// 지우기: 두 방 사이 벽은 빼고 두 방을 합친다. 방과 건물 바깥 사이 벽은 가상 경계선으로 바꾼다 (벽 삭제와 같다).
// 방 경계가 아닌 벽은 그냥 뺀다

import Foundation

/// 새 벽 그리기 규칙
enum WallDrawingRules {
    /// 이 각도(도)보다 덜 기울었으면 가로·세로로 맞춘다
    // TEMP: 맞춤 각도는 실기기에서 그려 보고 정함
    static let straightenAngle = 15.0
}

/// 그린 벽의 한쪽 끝이 어디에 붙는지
private enum WallEnd {
    /// 이미 있는 꼭짓점 (Vertex.id)
    case vertex(String)
    /// 이미 있는 벽 위의 점. 그 벽을 이 점에서 둘로 나눈다
    case wall(String, SIMD2<Double>)
}

// 그리기
extension PlanData {
    /// start → end 방향 직선을 양쪽으로 늘여 처음 부딪히는 벽 사이에 벽을 넣은 새 도면. snapRadius(m) 안의 꼭짓점에는 꼭짓점으로 붙인다.
    /// 어느 쪽이든 부딪히는 벽이 없거나, 너무 짧거나, 다른 벽을 가로지르거나, 스탬프에 걸리거나, 방을 다시 만들 수 없으면 nil
    func drawingWall(from start: SIMD2<Double>, to end: SIMD2<Double>, snapRadius: Double) -> PlanData? {
        let stroke = end - start
        let strokeLength = Self.length(stroke)
        guard strokeLength > WallMoveRules.eps else { return nil }
        let direction = Self.straightened(stroke / strokeLength)
        let strokeEnd = start + direction * (stroke * direction).sum()
        guard let startEnd = firstWall(from: start, toward: -direction, snapRadius: snapRadius),
              let endEnd = firstWall(from: strokeEnd, toward: direction, snapRadius: snapRadius),
              Self.length(point(of: endEnd) - point(of: startEnd)) >= WallMoveRules.minWallLength else { return nil }

        var result = self
        guard let model = walls.first(where: { !$0.isVirtual }),
              let startVertex = result.vertexId(for: startEnd),
              let endVertex = result.vertexId(for: endEnd),
              startVertex != endVertex,
              !result.hasWall(between: startVertex, and: endVertex) else { return nil }
        let wall = Wall(
            id: UUID().uuidString,
            startVertex: startVertex,
            endVertex: endVertex,
            thickness: model.thickness,
            height: model.height,
            isVirtual: false
        )
        guard !result.crossesWalls(wall) else { return nil }
        result.walls.append(wall)
        guard result.retraceRooms(splitsRooms: true) else { return nil }
        // 방 안에 잘 있던 사람·발화지점을 벽이 지나가면 그리지 않는다
        guard markers.filter(fits).allSatisfy(result.fits) else { return nil }
        result.refreshRoomLabels()
        return result
    }

    /// origin에서 direction으로 간 반직선이 처음 부딪히는 진짜 벽. 부딪힌 자리 가까이 꼭짓점이 있으면 그 꼭짓점.
    /// origin이 이미 벽 위면(snapRadius 안) 그 벽이 된다
    private func firstWall(from origin: SIMD2<Double>, toward direction: SIMD2<Double>, snapRadius: Double) -> WallEnd? {
        func cross(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double { a.x * b.y - a.y * b.x }
        var best: (id: String, line: WallLine, t: Double)?
        for wall in walls where !wall.isVirtual {
            guard let line = line(of: wall), line.length > WallMoveRules.eps else { continue }
            let span = line.end - line.start
            let denominator = cross(direction, span)
            guard abs(denominator) > WallMoveRules.eps else { continue }
            let offset = line.start - origin
            let t = cross(offset, span) / denominator
            let s = cross(offset, direction) / denominator
            let tolerance = snapRadius / line.length
            guard t >= -snapRadius, s >= -tolerance, s <= 1 + tolerance else { continue }
            if best == nil || t < best!.t { best = (wall.id, line, t) }
        }
        guard let best else { return nil }
        let hit = origin + direction * best.t
        let pos = vertexPoints
        let visibleVertices = Set(walls.filter { !$0.isVirtual }.flatMap { [$0.startVertex, $0.endVertex] })
        if let nearest = visibleVertices
            .compactMap({ id in pos[id].map { (id: id, distance: Self.length($0 - hit)) } })
            .min(by: { $0.distance < $1.distance }), nearest.distance <= snapRadius {
            return .vertex(nearest.id)
        }
        let along = min(max(((hit - best.line.start) * best.line.direction).sum(), 0), best.line.length)
        return .wall(best.id, best.line.point(along: along))
    }

    private func point(of end: WallEnd) -> SIMD2<Double> {
        switch end {
        case .vertex(let id):
            let vertex = vertex(id: id)
            return SIMD2(vertex?.x ?? 0, vertex?.y ?? 0)
        case .wall(_, let point):
            return point
        }
    }

    /// 거의 가로·세로인 방향이면 가로·세로로 맞춘 방향 (길이 1)
    private static func straightened(_ direction: SIMD2<Double>) -> SIMD2<Double> {
        let angle = atan2(abs(direction.y), abs(direction.x)) * 180 / .pi
        if angle < WallDrawingRules.straightenAngle { return SIMD2(direction.x < 0 ? -1 : 1, 0) }
        if angle > 90 - WallDrawingRules.straightenAngle { return SIMD2(0, direction.y < 0 ? -1 : 1) }
        return direction
    }

    /// 벽 끝이 쓸 꼭짓점 id. 벽 위면 그 벽을 나눈다. 벽을 나눌 수 없으면 nil
    private mutating func vertexId(for end: WallEnd) -> String? {
        switch end {
        case .vertex(let id):
            return id
        case .wall(let wallId, let point):
            return splitWall(wallId, at: point)
        }
    }

    /// 벽을 point에서 둘로 나누고 나눈 꼭짓점 id를 돌려준다.
    /// 뒤쪽 조각에 달린 창문·문·콘센트는 새 벽으로 옮긴다. 나누는 자리에 창문·문이 걸려 있으면 nil
    private mutating func splitWall(_ wallId: String, at point: SIMD2<Double>) -> String? {
        guard let index = walls.firstIndex(where: { $0.id == wallId }), let line = line(of: walls[index]) else { return nil }
        let at = ((point - line.start) * line.direction).sum()
        let eps = WallMoveRules.eps
        guard at > eps, at < line.length - eps else {
            return at <= eps ? walls[index].startVertex : walls[index].endVertex
        }
        guard !doorWindows.contains(where: { $0.wallId == wallId && abs($0.centerAlongWall - at) < $0.width / 2 }) else { return nil }

        let vertex = Vertex(id: UUID().uuidString, x: point.x, y: point.y)
        let front = walls[index]
        let back = Wall(id: UUID().uuidString, startVertex: vertex.id, endVertex: front.endVertex,
                        thickness: front.thickness, height: front.height, isVirtual: front.isVirtual)
        walls[index].endVertex = vertex.id
        vertices.append(vertex)
        walls.append(back)
        for i in doorWindows.indices where doorWindows[i].wallId == wallId && doorWindows[i].centerAlongWall > at {
            doorWindows[i].wallId = back.id
            doorWindows[i].centerAlongWall -= at
        }
        for i in wallFixtures.indices where wallFixtures[i].wallId == wallId && wallFixtures[i].positionAlongWall > at {
            wallFixtures[i].wallId = back.id
            wallFixtures[i].positionAlongWall -= at
        }
        // 방 경계도 벽 하나를 두 조각으로 바꾼다. 도는 방향이 반대면 뒤쪽 조각이 먼저다
        for r in rooms.indices {
            guard let at = rooms[r].boundary.firstIndex(where: { $0.wallId == wallId }) else { continue }
            let forward = rooms[r].boundary[at].forward
            let pieces = [RoomEdge(wallId: wallId, forward: forward), RoomEdge(wallId: back.id, forward: forward)]
            rooms[r].boundary.replaceSubrange(at...at, with: forward ? pieces : pieces.reversed())
        }
        return vertex.id
    }

    private func hasWall(between a: String, and b: String) -> Bool {
        walls.contains { Set([$0.startVertex, $0.endVertex]) == Set([a, b]) }
    }

    /// 벽이 꼭짓점을 함께 쓰지 않는 진짜 벽과 닿거나 가로지르는지
    func crossesWalls(_ wall: Wall) -> Bool {
        guard let new = line(of: wall) else { return true }
        let ends: Set = [wall.startVertex, wall.endVertex]
        return walls.contains { other in
            guard !other.isVirtual, ends.isDisjoint(with: [other.startVertex, other.endVertex]),
                  let line = line(of: other) else { return false }
            return Self.segmentsTouch(new, line)
        }
    }

    private static func segmentsTouch(_ p: WallLine, _ q: WallLine) -> Bool {
        func cross(_ o: SIMD2<Double>, _ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
            (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
        }
        let eps = WallMoveRules.eps
        let d1 = cross(q.start, q.end, p.start)
        let d2 = cross(q.start, q.end, p.end)
        let d3 = cross(p.start, p.end, q.start)
        let d4 = cross(p.start, p.end, q.end)
        if d1 * d2 < -eps, d3 * d4 < -eps { return true }
        // 한 끝이 다른 선분 위에 닿는 경우
        return p.distance(to: q.start) < eps || p.distance(to: q.end) < eps
            || q.distance(to: p.start) < eps || q.distance(to: p.end) < eps
    }

    private static func length(_ v: SIMD2<Double>) -> Double {
        (v * v).sum().squareRoot()
    }
}

// 지우기
extension PlanData {
    /// 지우개로 벽을 지운다. 양쪽이 모두 방이면 벽을 빼고 두 방을 합친다(같은 방이면 그대로 하나).
    /// 한쪽이 건물 바깥이면 가상 경계선으로 바꾼다. 방 경계가 아닌 벽은 그냥 뺀다
    mutating func eraseWall(id: String) {
        guard let wall = wall(id: id), !wall.isVirtual else { return }
        let roomSides = rooms.flatMap(\.boundary).filter { $0.wallId == id }
        switch roomSides.count {
        case 0:
            deleteWall(id: id)
        case 2:
            var merged = self
            merged.deleteWall(id: id)
            if merged.retraceRooms(mergesRooms: true) {
                // 합쳐져 남은 방은 이름을 새 방 가운데로 옮긴다
                for roomId in Set(roomSides.compactMap { side in rooms.first { $0.boundary.contains(side) }?.id }) {
                    merged.centerRoomLabel(id: roomId)
                }
                merged.refreshRoomLabels()
                self = merged
            } else {
                removeWall(id: id)
            }
        default:
            removeWall(id: id)
        }
    }

    /// 벽과 거기 달린 창문·문·콘센트를 빼고, 어느 벽도 쓰지 않게 된 꼭짓점도 뺀다
    private mutating func deleteWall(id: String) {
        walls.removeAll { $0.id == id }
        doorWindows.removeAll { $0.wallId == id }
        wallFixtures.removeAll { $0.wallId == id }
        let used = Set(walls.flatMap { [$0.startVertex, $0.endVertex] })
        vertices.removeAll { !used.contains($0.id) }
    }
}

// 펜으로 새 벽을 그리고 지우개로 벽을 지우는 계산
//
// 그리기: 그은 직선 한 줄. 양 끝을 각각 가까우면 붙고 멀면 그은 자리에서 끝난다 (꼭짓점 → 벽 → 조금 늘여 닿는 벽 → 떠 있는 끝).
// 벽에 붙을 때는 그 벽을 둘로 나눠 붙인다. 거의 가로·세로면 가로·세로로 맞춘다.
// 그리기는 거절하지 않는다. 다른 벽을 가로지르면 만나는 자리에서 나누고, 이미 벽이 있는 자리는 기존 벽을 남기고 겹치지 않는 부분만 벽으로 넣는다 (WallEditOutcome.swift)
// 지우기: 벽과 거기 달린 창문·문·콘센트를 뺀다

import Foundation

/// 새 벽 그리기 규칙
enum WallDrawingRules {
    /// 이 각도(도)보다 덜 기울었으면 가로·세로로 맞춘다
    // TEMP: 맞춤 각도는 실기기에서 그려 보고 정함
    static let straightenAngle = 2.0
    /// 끝점에서 그은 방향으로 이만큼(m) 안쪽만 늘이면 벽에 닿을 때 늘여서 붙인다
    // TEMP: 늘여 붙는 거리는 실기기에서 그려 보고 정함
    static let extendDistance = 0.5
    /// 도면에 벽이 하나도 없을 때 그리는 벽의 두께 (m). 스캔 변환이 주는 두께와 같다
    // TEMP: 벽 두께는 팀 논의 후 정함
    static let defaultThickness = 0.15
    /// 도면에 벽이 하나도 없을 때 그리는 벽의 높이 (m)
    // TEMP: 벽 높이는 팀 논의 후 정함
    static let defaultHeight = 2.4
}

extension PlanData {
    /// 모서리를 만들 두 직선 사이 각의 sin 하한 (약 6°). 이보다 나란하면 모서리를 만들지 않는다
    fileprivate static let cornerMinimumSine = 0.1
}

/// 그린 벽의 한쪽 끝이 어디에 붙는지
enum WallEnd {
    /// 이미 있는 꼭짓점 (Vertex.id)
    case vertex(String)
    /// 이미 있는 벽 위의 점. 그 벽을 이 점에서 둘로 나눈다
    case wall(String, SIMD2<Double>)
    /// 어디에도 붙지 않고 그은 자리에서 끝나는 떠 있는 끝. 새 꼭짓점을 만든다
    case free(SIMD2<Double>)
}

// 그리기
extension PlanData {
    /// start → end 직선 한 줄을 넣은 새 도면과 자동으로 지운 것. 양 끝은 각각 snapRadius(m) 안의 꼭짓점·벽에 붙고, 없으면 조금 늘여서 닿는 벽에 붙고,
    /// 그것도 없으면 그은 자리에서 끝난다(떠 있는 끝). 벽에 붙은 자리에 창문이 걸려 있으면 창문을 벽을 나눈 두 조각으로 나누고, 문이 걸려 있으면 문을 옆으로 민다.
    /// 거절하지 않는다. 넣을 벽이 없으면(이미 벽이 있는 자리 등) 도면을 바꾸지 않고 돌려준다
    func drawingWall(from start: SIMD2<Double>, to end: SIMD2<Double>, snapRadius: Double) -> WallEditOutcome {
        let unchanged = WallEditOutcome(plan: self)
        let stroke = end - start
        let strokeLength = Self.length(stroke)
        guard strokeLength > WallMoveRules.eps else { return unchanged }
        let direction = Self.straightened(stroke / strokeLength)
        let length = (stroke * direction).sum()
        // 두께·높이는 있는 벽을 베끼고, 벽이 하나도 없으면 기본값을 쓴다
        let model = walls.first
        let thickness = model?.thickness ?? WallDrawingRules.defaultThickness
        let height = model?.height ?? WallDrawingRules.defaultHeight

        // 두 끝이 모두 꼭짓점 가까이면 그 두 꼭짓점을 곧바로 잇는다. 가로·세로 맞춤이나 모서리 보정으로 벽이 어긋나지 않게 한다
        if let ends = connectedVertices(from: start, to: end, snapRadius: snapRadius) {
            var connected = self
            var removedByConnecting: [RemovedItem] = []
            guard connected.addWalls(from: ends.start, to: ends.end, thickness: thickness, height: height, removed: &removedByConnecting) else { return unchanged }
            connected.removeUnusedVertices(keeping: Set(vertices.map(\.id)))
            return WallEditOutcome(plan: connected, removed: removedByConnecting)
        }

        // 끝점은 하나씩 정해 바로 도면에 반영한다. 먼저 붙인 끝이 벽을 나눈 뒤의 도면에서 다음 끝을 찾아야 같은 벽 위의 두 끝도 맞는다.
        // 시작 끝이 정해지면 그 점을 지나는 직선 위에서 같은 길이만큼 가서 끝 끝을 찾아, 가로·세로로 맞춘 선이 꼭짓점에 붙어도 가로·세로를 유지한다
        var result = self
        var removed: [RemovedItem] = []
        let startEnd = result.resolveEnd(near: start, anchor: start, direction: direction, excluding: nil, snapRadius: snapRadius, removed: &removed)
        guard let startVertex = result.vertexId(for: startEnd, removed: &removed) else { return unchanged }
        let anchor = result.point(of: startEnd)
        let endEnd = result.resolveEnd(near: anchor + direction * length, anchor: anchor, direction: direction, excluding: startVertex, snapRadius: snapRadius, removed: &removed)
        guard let endVertex = result.vertexId(for: endEnd, removed: &removed), startVertex != endVertex else { return unchanged }

        guard result.addWalls(from: startVertex, to: endVertex, thickness: thickness, height: height, removed: &removed) else { return unchanged }
        result.removeUnusedVertices(keeping: Set(vertices.map(\.id)))
        return WallEditOutcome(plan: result, removed: removed)
    }

    /// 그은 선의 두 끝이 서로 다른 꼭짓점의 snapRadius 안이면 그 두 꼭짓점 id. 떨어진 두 모서리를 짧은 선으로 이을 때다
    private func connectedVertices(from start: SIMD2<Double>, to end: SIMD2<Double>, snapRadius: Double) -> (start: String, end: String)? {
        let pos = vertexPoints
        let used = Set(walls.flatMap { [$0.startVertex, $0.endVertex] })
        func nearestVertex(to point: SIMD2<Double>) -> String? {
            used.compactMap { id in pos[id].map { (id: id, distance: Self.length($0 - point)) } }
                .filter { $0.distance <= snapRadius }
                .min { $0.distance < $1.distance }?.id
        }
        guard let first = nearestVertex(to: start), let second = nearestVertex(to: end), first != second else { return nil }
        return (first, second)
    }

    /// 꼭짓점 from → to 직선을 벽으로 넣는다. 가로지르는 벽은 그 자리에서 나누고, 직선 위에 놓인 꼭짓점은 지나가며 이어진다.
    /// 이미 벽이 있는 구간은 기존 벽을 남기고 겹치지 않는 구간만 새 벽으로 넣는다. 넣은 것이 없으면 false
    private mutating func addWalls(from: String, to: String, thickness: Double, height: Double, removed: inout [RemovedItem]) -> Bool {
        let eps = WallMoveRules.eps
        let pos = vertexPoints
        guard let a = pos[from], let b = pos[to] else { return false }
        let line = WallLine(start: a, end: b)
        guard line.length > eps else { return false }

        // 새 선이 지나는 꼭짓점들 (거리순). 가로지르는 벽은 그 자리에서 나눠 꼭짓점을 만든다
        var cuts: [(t: Double, id: String)] = [(0, from), (line.length, to)]
        for wall in walls {
            guard let other = self.line(of: wall), let crossing = Self.crossingPoint(line, other),
                  let vertexId = splitWall(wall.id, at: crossing, removed: &removed) else { continue }
            cuts.append((((crossing - a) * line.direction).sum(), vertexId))
        }
        let used = Set(walls.flatMap { [$0.startVertex, $0.endVertex] })
        for (id, point) in vertexPoints where used.contains(id) && id != from && id != to && !cuts.contains(where: { $0.id == id }) {
            let along = ((point - a) * line.direction).sum()
            if line.distance(to: point) < eps, along > eps, along < line.length - eps { cuts.append((along, id)) }
        }
        cuts.sort { $0.t < $1.t }

        var didChange = false
        let points = vertexPoints
        for (first, second) in zip(cuts, cuts.dropFirst()) {
            if walls.contains(where: { Set([$0.startVertex, $0.endVertex]) == Set([first.id, second.id]) }) { continue }
            // 그 구간을 이미 벽이 지나면 기존 벽을 남긴다
            guard let p = points[first.id], let q = points[second.id] else { continue }
            let middle = (p + q) / 2
            let isCovered = walls.contains { wall in
                guard let other = self.line(of: wall) else { return false }
                return other.distance(to: middle) < eps
            }
            guard !isCovered else { continue }
            walls.append(Wall(id: UUID().uuidString, startVertex: first.id, endVertex: second.id, thickness: thickness, height: height))
            didChange = true
        }
        return didChange
    }

    /// 두 선분이 서로의 안쪽에서 가로지르는 점. 끝이 닿거나 나란하면 nil
    static func crossingPoint(_ p: WallLine, _ q: WallLine) -> SIMD2<Double>? {
        func cross(_ o: SIMD2<Double>, _ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
            (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
        }
        let eps = WallMoveRules.eps
        let d1 = cross(q.start, q.end, p.start)
        let d2 = cross(q.start, q.end, p.end)
        let d3 = cross(p.start, p.end, q.start)
        let d4 = cross(p.start, p.end, q.end)
        guard d1 * d2 < -eps, d3 * d4 < -eps else { return nil }
        return p.start + (p.end - p.start) * (d1 / (d1 - d2))
    }

    /// 그은 직선(anchor를 지나 direction 방향)의 한쪽 끝 point가 붙을 자리. 직선이 비뚤어지지 않게 붙는다:
    /// 가까운 꼭짓점이 떠 있는 벽의 끝이면 그 벽을 늘이거나 줄여 직선과 만나는 점에 모서리를 만들고(꼭짓점을 옮긴다),
    /// 여러 벽이 만나는 꼭짓점이면 직선이 그 벽과 만나는 점에 붙는다. 그 밖에는 wallEnd 규칙을 따른다.
    /// excluding은 붙지 않을 꼭짓점 (끝 끝이 시작 꼭짓점으로 되돌아오지 않게)
    private mutating func resolveEnd(near point: SIMD2<Double>, anchor: SIMD2<Double>, direction: SIMD2<Double>, excluding: String?, snapRadius: Double, removed: inout [RemovedItem]) -> WallEnd {
        let pos = vertexPoints
        let used = Set(walls.flatMap { [$0.startVertex, $0.endVertex] }).subtracting(excluding.map { [$0] } ?? [])
        func nearest(within radius: Double, where isCandidate: (String) -> Bool) -> [String] {
            used.compactMap { id in pos[id].map { (id: id, distance: Self.length($0 - point)) } }
                .filter { $0.distance <= radius && isCandidate($0.id) }
                .sorted { $0.distance < $1.distance }
                .map(\.id)
        }
        if let vertex = nearest(within: snapRadius, where: { _ in true }).first {
            if let corner = cornerWithFreeEnd(vertex, anchor: anchor, direction: direction, maxMove: snapRadius, removed: &removed) { return corner }
            if let onWall = wallPointOnLine(adjacentTo: vertex, anchor: anchor, direction: direction) { return onWall }
            return .vertex(vertex)
        }
        // 떠 있는 벽 끝이 조금 떨어져 있어도(늘여 붙는 거리 안) 두 벽을 늘이거나 줄여 모서리로 만든다
        for vertex in nearest(within: WallDrawingRules.extendDistance, where: { isFreeEnd($0) }) {
            if let corner = cornerWithFreeEnd(vertex, anchor: anchor, direction: direction, maxMove: WallDrawingRules.extendDistance, removed: &removed) { return corner }
        }
        let base = wallEnd(near: point, outward: direction * (point == anchor ? -1 : 1), snapRadius: snapRadius)
        // 벽 위에 붙을 때도 직선이 벽과 만나는 점으로 붙어 직선이 꺾이지 않는다
        if case .wall(let wallId, let hit) = base, let crossing = crossingOnWall(wallId, anchor: anchor, direction: direction),
           Self.length(crossing - hit) <= WallDrawingRules.extendDistance {
            return .wall(wallId, crossing)
        }
        return base
    }

    /// 꼭짓점이 벽 하나만 달린 떠 있는 끝인지
    func isFreeEnd(_ vertexId: String) -> Bool {
        walls.filter { $0.startVertex == vertexId || $0.endVertex == vertexId }.count == 1
    }

    /// 떠 있는 벽 끝 꼭짓점 vertexId를 그은 직선(anchor, direction)과 그 벽이 만나는 점으로 옮겨(벽을 늘이거나 줄여) 모서리를 만든다.
    /// 만나는 점까지가 maxMove(m) 안일 때만 옮긴다. 꼭짓점에 붙을 때는 붙는 거리, 떨어진 끝을 늘여 붙일 때는 늘여 붙는 거리다. 벽에 달린 창문·문·콘센트는 맞춘다(fitOpenings).
    /// 옮겼으면 그 꼭짓점, 못 옮기면 nil
    private mutating func cornerWithFreeEnd(_ vertexId: String, anchor: SIMD2<Double>, direction: SIMD2<Double>, maxMove: Double, removed: inout [RemovedItem]) -> WallEnd? {
        func cross(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double { a.x * b.y - a.y * b.x }
        guard isFreeEnd(vertexId),
              let wallIndex = walls.firstIndex(where: { $0.startVertex == vertexId || $0.endVertex == vertexId }),
              let line = line(of: walls[wallIndex]), line.length > WallMoveRules.eps,
              let vertexIndex = vertices.firstIndex(where: { $0.id == vertexId }) else { return nil }
        let wall = walls[wallIndex]
        let movesEnd = wall.endVertex == vertexId
        let fixed = movesEnd ? line.start : line.end
        let current = movesEnd ? line.end : line.start
        let along = (current - fixed) / line.length
        let denominator = cross(direction, along)
        // 거의 나란한 두 직선은 만나는 점이 멀리 달아나므로 모서리를 만들지 않는다
        guard abs(denominator) > Self.cornerMinimumSine else { return nil }
        let offset = fixed - anchor
        let newLength = cross(offset, direction) / denominator
        let corner = fixed + along * newLength
        guard newLength > WallMoveRules.eps, Self.length(corner - current) <= maxMove else { return nil }
        let placesBefore = attachedPlaces(onWalls: [wall.id])
        vertices[vertexIndex].x = corner.x
        vertices[vertexIndex].y = corner.y
        fitOpenings(onWalls: [wall.id], placesBefore: placesBefore, removed: &removed)
        return .vertex(vertexId)
    }

    /// 가로·세로로 맞춘 직선이 여러 벽이 만나는 꼭짓점 근처로 갈 때, 꼭짓점 대신 직선이 그 꼭짓점에 붙은 벽과 만나는 점에 붙는다. 직선 방향이 가로·세로가 아니면 nil
    private func wallPointOnLine(adjacentTo vertexId: String, anchor: SIMD2<Double>, direction: SIMD2<Double>) -> WallEnd? {
        guard abs(direction.x) == 1 || abs(direction.y) == 1, let vertex = vertexPoints[vertexId], !isFreeEnd(vertexId) else { return nil }
        var best: (id: String, point: SIMD2<Double>, distance: Double)?
        for wall in walls where wall.startVertex == vertexId || wall.endVertex == vertexId {
            guard let crossing = crossingOnWall(wall.id, anchor: anchor, direction: direction) else { continue }
            let distance = Self.length(crossing - vertex)
            if distance <= WallDrawingRules.extendDistance, best == nil || distance < best!.distance { best = (wall.id, crossing, distance) }
        }
        return best.map { .wall($0.id, $0.point) }
    }

    /// 직선(anchor, direction)이 벽 wallId의 선분과 만나는 점. 나란하거나 선분 밖이면 nil
    private func crossingOnWall(_ wallId: String, anchor: SIMD2<Double>, direction: SIMD2<Double>) -> SIMD2<Double>? {
        func cross(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double { a.x * b.y - a.y * b.x }
        guard let wall = wall(id: wallId), let line = line(of: wall), line.length > WallMoveRules.eps else { return nil }
        let span = line.end - line.start
        let denominator = cross(direction, span)
        guard abs(denominator) > WallMoveRules.eps else { return nil }
        let offset = line.start - anchor
        let t = cross(offset, span) / denominator
        let s = cross(offset, direction) / denominator
        guard s >= 0, s <= 1 else { return nil }
        return anchor + direction * t
    }

    /// 그은 선의 한쪽 끝 point가 붙을 자리. 앞 조건이 맞으면 거기서 멈춘다:
    /// ① snapRadius 안의 꼭짓점 (떠 있는 벽 끝도 포함) → ② 스캔 바닥 꼭짓점 → ③ snapRadius 안의 벽 → ④ 스캔 바닥 테두리 → ⑤ outward 방향으로 extendDistance 안쪽만 늘이면 닿는 벽·꼭짓점 → ⑥ 그은 자리의 떠 있는 끝
    func wallEnd(near point: SIMD2<Double>, outward: SIMD2<Double>, snapRadius: Double) -> WallEnd {
        let pos = vertexPoints
        let usedVertices = Set(walls.flatMap { [$0.startVertex, $0.endVertex] })
        let nearVertex = usedVertices
            .compactMap { id in pos[id].map { (id: id, distance: Self.length($0 - point)) } }
            .filter { $0.distance <= snapRadius }
            .min { $0.distance < $1.distance }
        if let nearVertex { return .vertex(nearVertex.id) }
        // 스캔한 바닥 꼭짓점: 바닥은 나누거나 바꾸지 않고 좌표만 빌린다
        if let corner = nearestFloorCorner(to: point, within: snapRadius) { return .free(corner) }

        var nearWall: (id: String, distance: Double)?
        for wall in walls {
            guard let line = line(of: wall), line.length > WallMoveRules.eps else { continue }
            let distance = line.distance(to: point)
            if distance <= snapRadius, nearWall == nil || distance < nearWall!.distance { nearWall = (wall.id, distance) }
        }
        if let nearWall, let line = wall(id: nearWall.id).flatMap({ line(of: $0) }) {
            let along = min(max(((point - line.start) * line.direction).sum(), 0), line.length)
            return .wall(nearWall.id, line.point(along: along))
        }

        // 스캔한 바닥 테두리: 바닥 모양을 따라 벽을 그을 수 있게 테두리 위 점을 빌린다
        if let edgePoint = nearestFloorEdgePoint(to: point, within: snapRadius) { return .free(edgePoint) }

        if let extended = extendedEnd(from: point, toward: outward, snapRadius: snapRadius) { return extended }
        return .free(point)
    }

    /// 점에서 radius(m) 안의 가장 가까운 스캔 바닥 꼭짓점
    private func nearestFloorCorner(to point: SIMD2<Double>, within radius: Double) -> SIMD2<Double>? {
        (floors ?? []).flatMap(\.points)
            .map { (point: $0, distance: Self.length($0 - point)) }
            .filter { $0.distance <= radius }
            .min { $0.distance < $1.distance }?.point
    }

    /// 점에서 radius(m) 안의 가장 가까운 스캔 바닥 테두리 위의 점
    private func nearestFloorEdgePoint(to point: SIMD2<Double>, within radius: Double) -> SIMD2<Double>? {
        (floors ?? []).compactMap { $0.nearestEdgePoint(to: point) }
            .filter { $0.distance <= radius }
            .min { $0.distance < $1.distance }?.point
    }

    /// origin에서 direction으로 extendDistance 안쪽만 가면 처음 닿는 벽 또는 꼭짓점.
    /// 닿은 자리 가까이 꼭짓점이 있으면 그 꼭짓점. 선과 나란한 벽은 끝 꼭짓점이 선 위에 놓일 때만 닿은 것으로 본다
    private func extendedEnd(from origin: SIMD2<Double>, toward direction: SIMD2<Double>, snapRadius: Double) -> WallEnd? {
        func cross(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double { a.x * b.y - a.y * b.x }
        let limit = WallDrawingRules.extendDistance
        var best: (end: WallEnd, t: Double)?
        let pos = vertexPoints
        let visibleVertices = Set(walls.flatMap { [$0.startVertex, $0.endVertex] })
        // 선 위에 놓인 꼭짓점
        for id in visibleVertices {
            guard let vertex = pos[id] else { continue }
            let offset = vertex - origin
            let t = (offset * direction).sum()
            guard t > 0, t <= limit, abs(cross(direction, offset)) <= snapRadius else { continue }
            if best == nil || t < best!.t { best = (.vertex(id), t) }
        }
        // 선과 만나는 벽
        for wall in walls {
            guard let line = line(of: wall), line.length > WallMoveRules.eps else { continue }
            let span = line.end - line.start
            let denominator = cross(direction, span)
            guard abs(denominator) > WallMoveRules.eps else { continue }
            let offset = line.start - origin
            let t = cross(offset, span) / denominator
            let s = cross(offset, direction) / denominator
            let tolerance = snapRadius / line.length
            guard t > 0, t <= limit, s >= -tolerance, s <= 1 + tolerance else { continue }
            guard best == nil || t < best!.t else { continue }
            let hit = origin + direction * t
            if let nearest = visibleVertices
                .compactMap({ id in pos[id].map { (id: id, distance: Self.length($0 - hit)) } })
                .min(by: { $0.distance < $1.distance }), nearest.distance <= snapRadius {
                best = (.vertex(nearest.id), t)
            } else {
                let along = min(max(((hit - line.start) * line.direction).sum(), 0), line.length)
                best = (.wall(wall.id, line.point(along: along)), t)
            }
        }
        return best?.end
    }

    private func point(of end: WallEnd) -> SIMD2<Double> {
        switch end {
        case .vertex(let id):
            let vertex = vertex(id: id)
            return SIMD2(vertex?.x ?? 0, vertex?.y ?? 0)
        case .wall(_, let point), .free(let point):
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

    /// 벽 끝이 쓸 꼭짓점 id. 벽 위면 그 벽을 나눈다. 벽을 찾지 못하면 nil
    mutating func vertexId(for end: WallEnd, removed: inout [RemovedItem]) -> String? {
        switch end {
        case .vertex(let id):
            return id
        case .wall(let wallId, let point):
            return splitWall(wallId, at: point, removed: &removed)
        case .free(let point):
            let vertex = Vertex(id: UUID().uuidString, x: point.x, y: point.y)
            vertices.append(vertex)
            return vertex.id
        }
    }

    /// 벽을 point에서 둘로 나누고 나눈 꼭짓점 id를 돌려준다. reusing이 있으면 새 꼭짓점을 만들지 않고 그 꼭짓점에서 나눈다.
    /// 뒤쪽 조각에 달린 창문·문·콘센트는 새 벽으로 옮긴다. 나누는 자리에 걸친 창문은 두 조각으로 나눠 양쪽 벽에 하나씩 둔다
    /// (너무 좁아지는 조각은 뺀다). 나누는 자리에 문이 걸려 있으면 문을 옆으로 밀고, 자리가 없으면 지우고 removed에 적는다. 벽을 찾지 못하면 nil
    mutating func splitWall(_ wallId: String, at point: SIMD2<Double>, reusing existing: String? = nil, removed: inout [RemovedItem]) -> String? {
        guard let index = walls.firstIndex(where: { $0.id == wallId }), let line = line(of: walls[index]) else { return nil }
        let at = ((point - line.start) * line.direction).sum()
        let eps = WallMoveRules.eps
        guard at > eps, at < line.length - eps else {
            return at <= eps ? walls[index].startVertex : walls[index].endVertex
        }
        pushDoors(offSplitAt: at, onWall: wallId, length: line.length, removed: &removed)

        let vertex: Vertex
        if let existing, let found = self.vertex(id: existing) {
            vertex = found
        } else {
            vertex = Vertex(id: UUID().uuidString, x: point.x, y: point.y)
            vertices.append(vertex)
        }
        let front = walls[index]
        let back = Wall(id: UUID().uuidString, startVertex: vertex.id, endVertex: front.endVertex,
                        thickness: front.thickness, height: front.height)
        walls[index].endVertex = vertex.id
        walls.append(back)
        var addedPieces: [DoorWindow] = []
        var removedIds = Set<String>()
        for i in doorWindows.indices where doorWindows[i].wallId == wallId {
            let piece = doorWindows[i]
            let pieceStart = piece.centerAlongWall - piece.width / 2
            let pieceEnd = piece.centerAlongWall + piece.width / 2
            if pieceStart < at, pieceEnd > at {
                // 나누는 자리에 걸친 창문: 앞 조각은 그대로 두고 크기만 줄이고, 뒤 조각은 새 벽에 새로 단다
                let frontWidth = at - pieceStart
                let backWidth = pieceEnd - at
                if frontWidth >= Self.minimumWindowSize {
                    doorWindows[i].width = frontWidth
                    doorWindows[i].centerAlongWall = pieceStart + frontWidth / 2
                } else {
                    removedIds.insert(piece.id)
                }
                if backWidth >= Self.minimumWindowSize {
                    addedPieces.append(DoorWindow(
                        id: UUID().uuidString, wallId: back.id, kind: piece.kind,
                        centerAlongWall: backWidth / 2, width: backWidth, sillHeight: piece.sillHeight, height: piece.height
                    ))
                }
            } else if pieceStart >= at {
                doorWindows[i].wallId = back.id
                doorWindows[i].centerAlongWall -= at
            }
        }
        doorWindows.removeAll { removedIds.contains($0.id) }
        doorWindows.append(contentsOf: addedPieces)
        for i in wallFixtures.indices where wallFixtures[i].wallId == wallId && wallFixtures[i].positionAlongWall > at {
            wallFixtures[i].wallId = back.id
            wallFixtures[i].positionAlongWall -= at
        }
        return vertex.id
    }

    static func length(_ v: SIMD2<Double>) -> Double {
        (v * v).sum().squareRoot()
    }
}

// 지우기
extension PlanData {
    /// 지우개로 벽을 지운다. 벽과 거기 달린 창문·문·콘센트를 빼고, 어느 벽도 쓰지 않게 된 꼭짓점도 뺀다.
    /// 공간 라벨은 자리(점)만 갖고 있어 그대로 둔다
    mutating func eraseWall(id: String) {
        walls.removeAll { $0.id == id }
        doorWindows.removeAll { $0.wallId == id }
        wallFixtures.removeAll { $0.wallId == id }
        let used = Set(walls.flatMap { [$0.startVertex, $0.endVertex] })
        vertices.removeAll { !used.contains($0.id) }
    }
}

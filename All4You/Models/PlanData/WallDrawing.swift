// 펜으로 새 벽을 그리고 지우개로 벽을 지우는 계산
//
// 그리기: 그은 직선 한 줄. 양 끝을 각각 가까우면 붙고 멀면 그은 자리에서 끝난다 (꼭짓점 → 벽 → 조금 늘여 닿는 벽 → 떠 있는 끝).
// 벽에 붙을 때는 그 벽을 둘로 나눠 붙인다. 거의 가로·세로면 가로·세로로 맞춘다. 새 벽이 방을 닫으면 방을 나눈다.
// 지우기: 두 방 사이 벽은 빼고 두 방을 합친다. 방과 건물 바깥 사이 벽은 가상 경계선으로 바꾼다 (벽 삭제와 같다).
// 방 경계가 아닌 벽은 그냥 뺀다. 지운 뒤에는 쓸모없어진 가상 경계선을 정리한다 (VirtualWallCleanup.swift)

import Foundation

/// 새 벽 그리기 규칙
enum WallDrawingRules {
    /// 이 각도(도)보다 덜 기울었으면 가로·세로로 맞춘다
    // TEMP: 맞춤 각도는 실기기에서 그려 보고 정함
    static let straightenAngle = 15.0
    /// 끝점에서 그은 방향으로 이만큼(m) 안쪽만 늘이면 벽에 닿을 때 늘여서 붙인다
    // TEMP: 늘여 붙는 거리는 실기기에서 그려 보고 정함
    static let extendDistance = 0.5
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

/// 긋는 중인 선의 한쪽 끝이 붙을 자리
struct WallEndPreview: Equatable {
    /// 도면 점 (m)
    let point: SIMD2<Double>
    /// 꼭짓점·벽에 붙는지. false면 그은 자리에서 끝나는 떠 있는 끝
    let isAttached: Bool
}

/// 벽을 그리지 못한 이유. message는 화면에 띄워, 어떻게 다시 그으면 되는지 알려 주는 문장이다
enum WallDrawingFailure: Error {
    case strokeTooShort
    case wallTooShort
    case doorInTheWay
    case wallAlreadyThere
    case crossesWall
    case roomsCannotBeRebuilt
    case stampInTheWay

    var message: String {
        switch self {
        case .strokeTooShort: "선이 너무 짧아요. 조금 더 길게 그어 주세요"
        case .wallTooShort: "벽이 너무 짧아요(0.3m 미만). 조금 더 길게 그어 주세요"
        case .doorInTheWay: "문이 있는 자리에는 벽을 붙일 수 없어요. 문에서 떨어진 벽 자리에서 시작하거나 끝나게 그어 주세요"
        case .wallAlreadyThere: "그 자리에는 이미 벽이 있어요. 벽이 없는 다른 자리에 그어 주세요"
        case .crossesWall: "다른 벽을 가로질러요. 다른 벽을 지나지 않게 그어 주세요"
        case .roomsCannotBeRebuilt: "벽으로 방을 나눌 수 없어요. 벽이 끊기지 않고 이어진 방 안에서 그어 주세요"
        case .stampInTheWay: "스탬프가 걸려요. 발화지점·피해자에서 떨어진 자리에 그어 주세요"
        }
    }
}

// 그리기
extension PlanData {
    /// start → end 직선 한 줄을 넣은 새 도면. 양 끝은 각각 snapRadius(m) 안의 꼭짓점·벽에 붙고, 없으면 조금 늘여서 닿는 벽에 붙고,
    /// 그것도 없으면 그은 자리에서 끝난다(떠 있는 끝). 벽에 붙은 자리에 창문이 걸려 있으면 창문을 벽을 나눈 두 조각으로 나눈다.
    /// 너무 짧거나, 문이 걸리거나, 다른 벽을 가로지르거나, 스탬프에 걸리거나, 방을 다시 만들 수 없으면 그 이유(failure)
    func drawingWall(from start: SIMD2<Double>, to end: SIMD2<Double>, snapRadius: Double) -> Result<PlanData, WallDrawingFailure> {
        let stroke = end - start
        let strokeLength = Self.length(stroke)
        guard strokeLength > WallMoveRules.eps else { return .failure(.strokeTooShort) }
        let direction = Self.straightened(stroke / strokeLength)
        let length = (stroke * direction).sum()
        guard let model = walls.first(where: { !$0.isVirtual }) else { return .failure(.wallAlreadyThere) }

        // 끝점은 하나씩 정해 바로 도면에 반영한다. 먼저 붙인 끝이 벽을 나눈 뒤의 도면에서 다음 끝을 찾아야 같은 벽 위의 두 끝도 맞는다.
        // 시작 끝이 정해지면 그 점을 지나는 직선 위에서 같은 길이만큼 가서 끝 끝을 찾아, 가로·세로로 맞춘 선이 꼭짓점에 붙어도 가로·세로를 유지한다
        var result = self
        let startEnd = result.resolveEnd(near: start, anchor: start, direction: direction, excluding: nil, snapRadius: snapRadius)
        guard !result.isDoorInTheWay(startEnd), let startVertex = result.vertexId(for: startEnd) else { return .failure(.doorInTheWay) }
        let anchor = result.point(of: startEnd)
        let endEnd = result.resolveEnd(near: anchor + direction * length, anchor: anchor, direction: direction, excluding: startVertex, snapRadius: snapRadius)
        guard Self.length(result.point(of: endEnd) - anchor) >= WallMoveRules.minWallLength else { return .failure(.wallTooShort) }
        guard !result.isDoorInTheWay(endEnd), let endVertex = result.vertexId(for: endEnd) else { return .failure(.doorInTheWay) }
        guard startVertex != endVertex else { return .failure(.wallAlreadyThere) }

        // 가상 경계선을 가로지르면 만나는 자리에 꼭짓점을 만들어 가상 경계선과 새 벽을 모두 나눈다
        guard let chain = result.verticesAlong(from: startVertex, to: endVertex) else { return .failure(.roomsCannotBeRebuilt) }
        var drawnWallIds = Set<String>()
        for (a, b) in zip(chain, chain.dropFirst()) {
            if let existing = result.walls.firstIndex(where: { Set([$0.startVertex, $0.endVertex]) == Set([a, b]) }) {
                // 이미 있는 가상 경계선이면 진짜 벽으로 바꾼다. 진짜 벽이면 그대로 둔다
                guard result.walls[existing].isVirtual else { continue }
                result.walls[existing].isVirtual = false
                result.walls[existing].thickness = model.thickness
                result.walls[existing].height = model.height
                drawnWallIds.insert(result.walls[existing].id)
                continue
            }
            let wall = Wall(id: UUID().uuidString, startVertex: a, endVertex: b, thickness: model.thickness, height: model.height, isVirtual: false)
            guard !result.crossesWalls(wall) else { return .failure(.crossesWall) }
            result.walls.append(wall)
            drawnWallIds.insert(wall.id)
        }
        guard !drawnWallIds.isEmpty else { return .failure(.wallAlreadyThere) }
        guard result.retraceRooms(splitsRooms: true) else { return .failure(.roomsCannotBeRebuilt) }
        // 쓸모없어진 가상 경계선을 정리한 뒤에 새 방을 만들어야, 지워진 방의 칸이 "새 공간"으로 되살아나지 않는다
        result.cleanUpVirtualWalls()
        // 새 벽이 방 밖에서 칸을 닫았으면 그 칸을 "새 공간"으로 만든다
        result.addRoomsClosed(by: drawnWallIds)
        // 방 안에 잘 있던 사람·발화지점을 벽이 지나가면 그리지 않는다
        guard markers.filter(fits).allSatisfy(result.fits) else { return .failure(.stampInTheWay) }
        result.refreshRoomLabels()
        return .success(result)
    }

    /// 꼭짓점 from → to 직선이 가로지르는 가상 경계선을 그 자리에서 나눠, from에서 to까지 차례로 지나는 꼭짓점 id들을 돌려준다
    /// (from, 가로지른 자리들, to). 가로지른 가상 경계선이 없으면 [from, to]. 경계선을 나눌 수 없으면 nil
    private mutating func verticesAlong(from: String, to: String) -> [String]? {
        let pos = vertexPoints
        guard let a = pos[from], let b = pos[to] else { return nil }
        let line = WallLine(start: a, end: b)
        var cuts: [(t: Double, wallId: String, point: SIMD2<Double>)] = []
        for wall in walls where wall.isVirtual {
            guard ![wall.startVertex, wall.endVertex].contains(from), ![wall.startVertex, wall.endVertex].contains(to),
                  let other = self.line(of: wall), let crossing = Self.crossingPoint(line, other) else { continue }
            cuts.append((((crossing - a) * line.direction).sum(), wall.id, crossing))
        }
        var chain = [from]
        for cut in cuts.sorted(by: { $0.t < $1.t }) {
            guard let vertex = splitWall(cut.wallId, at: cut.point) else { return nil }
            chain.append(vertex)
        }
        chain.append(to)
        return chain
    }

    /// 두 선분이 서로의 안쪽에서 가로지르는 점. 끝이 닿거나 나란하면 nil
    private static func crossingPoint(_ p: WallLine, _ q: WallLine) -> SIMD2<Double>? {
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

    /// 긋는 동안 보여 줄 양 끝이 붙을 자리. 손을 떼면 drawingWall이 정할 자리와 같은 규칙이다 (복사본에서 같은 순서로 정한다)
    func wallEndPreviews(from start: SIMD2<Double>, to end: SIMD2<Double>, snapRadius: Double) -> (start: WallEndPreview, end: WallEndPreview)? {
        let stroke = end - start
        let strokeLength = Self.length(stroke)
        guard strokeLength > WallMoveRules.eps else { return nil }
        let direction = Self.straightened(stroke / strokeLength)
        let length = (stroke * direction).sum()
        func preview(_ end: WallEnd, in plan: PlanData) -> WallEndPreview {
            if case .free = end { return WallEndPreview(point: plan.point(of: end), isAttached: false) }
            return WallEndPreview(point: plan.point(of: end), isAttached: true)
        }
        var copy = self
        let startEnd = copy.resolveEnd(near: start, anchor: start, direction: direction, excluding: nil, snapRadius: snapRadius)
        let startVertex = copy.vertexId(for: startEnd)
        let anchor = copy.point(of: startEnd)
        let endEnd = copy.resolveEnd(near: anchor + direction * length, anchor: anchor, direction: direction, excluding: startVertex, snapRadius: snapRadius)
        return (preview(startEnd, in: copy), preview(endEnd, in: copy))
    }

    /// 벽 끝이 붙을 자리에 문이 걸려 있는지. 창문·개구부는 나눌 수 있어서 걸리지 않는다
    func isDoorInTheWay(_ end: WallEnd) -> Bool {
        guard case .wall(let wallId, let point) = end, let wall = wall(id: wallId), let line = line(of: wall) else { return false }
        let at = ((point - line.start) * line.direction).sum()
        return doorWindows.contains { $0.wallId == wallId && $0.kind == .door && abs($0.centerAlongWall - at) < $0.width / 2 }
    }

    /// 그은 직선(anchor를 지나 direction 방향)의 한쪽 끝 point가 붙을 자리. 직선이 비뚤어지지 않게 붙는다:
    /// 가까운 꼭짓점이 떠 있는 벽의 끝이면 그 벽을 늘이거나 줄여 직선과 만나는 점에 모서리를 만들고(꼭짓점을 옮긴다),
    /// 여러 벽이 만나는 꼭짓점이면 직선이 그 벽과 만나는 점에 붙는다. 그 밖에는 wallEnd 규칙을 따른다.
    /// excluding은 붙지 않을 꼭짓점 (끝 끝이 시작 꼭짓점으로 되돌아오지 않게)
    private mutating func resolveEnd(near point: SIMD2<Double>, anchor: SIMD2<Double>, direction: SIMD2<Double>, excluding: String?, snapRadius: Double) -> WallEnd {
        let pos = vertexPoints
        let used = Set(walls.flatMap { [$0.startVertex, $0.endVertex] }).subtracting(excluding.map { [$0] } ?? [])
        func nearest(within radius: Double, where isCandidate: (String) -> Bool) -> [String] {
            used.compactMap { id in pos[id].map { (id: id, distance: Self.length($0 - point)) } }
                .filter { $0.distance <= radius && isCandidate($0.id) }
                .sorted { $0.distance < $1.distance }
                .map(\.id)
        }
        if let vertex = nearest(within: snapRadius, where: { _ in true }).first {
            if let corner = cornerWithFreeEnd(vertex, anchor: anchor, direction: direction) { return corner }
            if let onWall = wallPointOnLine(adjacentTo: vertex, anchor: anchor, direction: direction) { return onWall }
            return .vertex(vertex)
        }
        // 떠 있는 벽 끝이 조금 떨어져 있어도(늘여 붙는 거리 안) 두 벽을 늘이거나 줄여 모서리로 만든다
        for vertex in nearest(within: WallDrawingRules.extendDistance, where: { isFreeEnd($0) }) {
            if let corner = cornerWithFreeEnd(vertex, anchor: anchor, direction: direction) { return corner }
        }
        let base = wallEnd(near: point, outward: direction * (point == anchor ? -1 : 1), snapRadius: snapRadius)
        // 벽 위에 붙을 때도 직선이 벽과 만나는 점으로 붙어 직선이 꺾이지 않는다
        if case .wall(let wallId, let hit) = base, let crossing = crossingOnWall(wallId, anchor: anchor, direction: direction),
           Self.length(crossing - hit) <= WallDrawingRules.extendDistance {
            return .wall(wallId, crossing)
        }
        return base
    }

    /// 꼭짓점이 벽 하나만 달린 떠 있는 끝인지 (가상 경계선이 달려 있으면 아님)
    func isFreeEnd(_ vertexId: String) -> Bool {
        let attached = walls.filter { $0.startVertex == vertexId || $0.endVertex == vertexId }
        return attached.count == 1 && !attached[0].isVirtual
    }

    /// 떠 있는 벽 끝 꼭짓점 vertexId를 그은 직선(anchor, direction)과 그 벽이 만나는 점으로 옮겨(벽을 늘이거나 줄여) 모서리를 만든다.
    /// 만나는 점까지가 늘여 붙는 거리 안이고, 줄어든 벽이 최소 길이 이상이고, 벽의 창문·문·콘센트가 벽 밖으로 나가지 않을 때만 옮긴다.
    /// 옮겼으면 그 꼭짓점, 못 옮기면 nil
    private mutating func cornerWithFreeEnd(_ vertexId: String, anchor: SIMD2<Double>, direction: SIMD2<Double>) -> WallEnd? {
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
        guard newLength >= WallMoveRules.minWallLength, Self.length(corner - current) <= WallDrawingRules.extendDistance else { return nil }
        // 시작 쪽을 옮기면 벽을 따라 잰 거리의 기준이 바뀌므로 달린 것들의 자리를 그만큼 민다
        let shift = movesEnd ? 0 : line.length - newLength
        let openings = doorWindows.indices.filter { doorWindows[$0].wallId == wall.id }
        let fixtures = wallFixtures.indices.filter { wallFixtures[$0].wallId == wall.id }
        let eps = WallMoveRules.eps
        for index in openings {
            let start = doorWindows[index].centerAlongWall - shift - doorWindows[index].width / 2
            guard start >= -eps, start + doorWindows[index].width <= newLength + eps else { return nil }
        }
        for index in fixtures {
            let position = wallFixtures[index].positionAlongWall - shift
            guard position >= -eps, position <= newLength + eps else { return nil }
        }
        for index in openings { doorWindows[index].centerAlongWall -= shift }
        for index in fixtures { wallFixtures[index].positionAlongWall -= shift }
        vertices[vertexIndex].x = corner.x
        vertices[vertexIndex].y = corner.y
        return .vertex(vertexId)
    }

    /// 가로·세로로 맞춘 직선이 여러 벽이 만나는 꼭짓점 근처로 갈 때, 꼭짓점 대신 직선이 그 꼭짓점에 붙은 벽과 만나는 점에 붙는다. 직선 방향이 가로·세로가 아니면 nil
    private func wallPointOnLine(adjacentTo vertexId: String, anchor: SIMD2<Double>, direction: SIMD2<Double>) -> WallEnd? {
        guard abs(direction.x) == 1 || abs(direction.y) == 1, let vertex = vertexPoints[vertexId], !isFreeEnd(vertexId) else { return nil }
        var best: (id: String, point: SIMD2<Double>, distance: Double)?
        for wall in walls where !wall.isVirtual && (wall.startVertex == vertexId || wall.endVertex == vertexId) {
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
    /// ① snapRadius 안의 꼭짓점 (떠 있는 벽 끝도 포함) → ② snapRadius 안의 벽 → ③ outward 방향으로 extendDistance 안쪽만 늘이면 닿는 벽·꼭짓점 → ④ 그은 자리의 떠 있는 끝
    func wallEnd(near point: SIMD2<Double>, outward: SIMD2<Double>, snapRadius: Double) -> WallEnd {
        let pos = vertexPoints
        let usedVertices = Set(walls.flatMap { [$0.startVertex, $0.endVertex] })
        let nearVertex = usedVertices
            .compactMap { id in pos[id].map { (id: id, distance: Self.length($0 - point)) } }
            .filter { $0.distance <= snapRadius }
            .min { $0.distance < $1.distance }
        if let nearVertex { return .vertex(nearVertex.id) }

        // 벽 위에는 가상 경계선도 붙을 수 있다 (스캔 틈을 메울 때 틈의 일부만 그을 수 있게)
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

        if let extended = extendedEnd(from: point, toward: outward, snapRadius: snapRadius) { return extended }
        return .free(point)
    }

    /// origin에서 direction으로 extendDistance 안쪽만 가면 처음 닿는 벽 또는 꼭짓점.
    /// 닿은 자리 가까이 꼭짓점이 있으면 그 꼭짓점. 선과 나란한 벽은 끝 꼭짓점이 선 위에 놓일 때만 닿은 것으로 본다
    private func extendedEnd(from origin: SIMD2<Double>, toward direction: SIMD2<Double>, snapRadius: Double) -> WallEnd? {
        func cross(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double { a.x * b.y - a.y * b.x }
        let limit = WallDrawingRules.extendDistance
        var best: (end: WallEnd, t: Double)?
        let pos = vertexPoints
        let visibleVertices = Set(walls.filter { !$0.isVirtual }.flatMap { [$0.startVertex, $0.endVertex] })
        // 선 위에 놓인 꼭짓점
        for id in visibleVertices {
            guard let vertex = pos[id] else { continue }
            let offset = vertex - origin
            let t = (offset * direction).sum()
            guard t > 0, t <= limit, abs(cross(direction, offset)) <= snapRadius else { continue }
            if best == nil || t < best!.t { best = (.vertex(id), t) }
        }
        // 선과 만나는 벽
        for wall in walls where !wall.isVirtual {
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

    /// 벽 끝이 쓸 꼭짓점 id. 벽 위면 그 벽을 나눈다. 벽을 나눌 수 없으면 nil
    mutating func vertexId(for end: WallEnd) -> String? {
        switch end {
        case .vertex(let id):
            return id
        case .wall(let wallId, let point):
            return splitWall(wallId, at: point)
        case .free(let point):
            let vertex = Vertex(id: UUID().uuidString, x: point.x, y: point.y)
            vertices.append(vertex)
            return vertex.id
        }
    }

    /// 벽을 point에서 둘로 나누고 나눈 꼭짓점 id를 돌려준다.
    /// 뒤쪽 조각에 달린 창문·문·콘센트는 새 벽으로 옮긴다. 나누는 자리에 걸친 창문은 두 조각으로 나눠 양쪽 벽에 하나씩 둔다
    /// (너무 좁아지는 조각은 뺀다). 나누는 자리에 문이 걸려 있으면 nil
    mutating func splitWall(_ wallId: String, at point: SIMD2<Double>) -> String? {
        guard let index = walls.firstIndex(where: { $0.id == wallId }), let line = line(of: walls[index]) else { return nil }
        let at = ((point - line.start) * line.direction).sum()
        let eps = WallMoveRules.eps
        guard at > eps, at < line.length - eps else {
            return at <= eps ? walls[index].startVertex : walls[index].endVertex
        }
        guard !doorWindows.contains(where: { $0.wallId == wallId && $0.kind == .door && abs($0.centerAlongWall - at) < $0.width / 2 }) else { return nil }

        let vertex = Vertex(id: UUID().uuidString, x: point.x, y: point.y)
        let front = walls[index]
        let back = Wall(id: UUID().uuidString, startVertex: vertex.id, endVertex: front.endVertex,
                        thickness: front.thickness, height: front.height, isVirtual: front.isVirtual)
        walls[index].endVertex = vertex.id
        vertices.append(vertex)
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
        // 방 경계도 벽 하나를 두 조각으로 바꾼다. 도는 방향이 반대면 뒤쪽 조각이 먼저다
        for r in rooms.indices {
            guard let at = rooms[r].boundary.firstIndex(where: { $0.wallId == wallId }) else { continue }
            let forward = rooms[r].boundary[at].forward
            let pieces = [RoomEdge(wallId: wallId, forward: forward), RoomEdge(wallId: back.id, forward: forward)]
            rooms[r].boundary.replaceSubrange(at...at, with: forward ? pieces : pieces.reversed())
        }
        return vertex.id
    }

    func hasWall(between a: String, and b: String) -> Bool {
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

    static func segmentsTouch(_ p: WallLine, _ q: WallLine) -> Bool {
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

    static func length(_ v: SIMD2<Double>) -> Double {
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
        // 지워서 쓸모없어진 가상 경계선을 정리한다. 지우개 한 번이 되돌리기 한 칸이 되도록 같은 변경 안에서 한다
        cleanUpVirtualWalls()
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

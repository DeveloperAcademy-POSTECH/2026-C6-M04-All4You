// 꼭짓점 하나를 끌어 옮기는 계산. 꼭짓점에 붙은 벽이 함께 늘고 줄며, 벽이 가로·세로가 되는 자리 근처에서는 딱 붙는다.
// 곧은 벽 중간에 있는 꼭짓점(T자로 붙은 자리 등)은 그 벽의 선을 따라서만 미끄러지고, 떠 있는 벽 끝은 놓은 자리 가까이 다른 벽·꼭짓점이 있으면 붙는다.
// 옮길 수 없는 자리면 그 이유를 돌려준다 (벽이 너무 짧아짐, 다른 벽을 가로지름, 창문·문·콘센트가 벽 밖으로 나감, 스탬프에 걸림, 방을 다시 만들 수 없음)

import Foundation

/// 꼭짓점을 옮기지 못한 이유. message는 화면에 띄워, 어떻게 다시 끌면 되는지 알려 주는 문장이다
enum VertexMoveFailure: Error {
    case vertexNotFound
    case wallTooShort
    case crossesWall
    case openingOutsideWall
    case stampInTheWay
    case roomsCannotBeRebuilt

    var message: String {
        switch self {
        case .vertexNotFound: "옮길 모서리를 찾지 못했어요. 벽을 다시 골라 주세요"
        case .wallTooShort: "벽이 너무 짧아져요(0.3m 미만). 조금 덜 옮겨 주세요"
        case .crossesWall: "다른 벽과 부딪혀요. 다른 벽을 지나지 않는 자리로 옮겨 주세요"
        case .openingOutsideWall: "벽에 달린 창문·문·콘센트가 벽 밖으로 나가요. 벽을 덜 줄여 주세요"
        case .stampInTheWay: "스탬프가 걸려요. 발화지점·피해자에서 떨어진 자리로 옮겨 주세요"
        case .roomsCannotBeRebuilt: "방을 다시 만들 수 없어요. 벽이 끊기지 않는 자리로 옮겨 주세요"
        }
    }
}

extension PlanData {
    /// 꼭짓점 vertexId를 도면 점 target(m)으로 옮긴 새 도면. snapRadius(m) 안에서는 축 자석(가로·세로)과 떠 있는 끝 붙이기가 맞춰 준다
    func movingVertex(_ vertexId: String, to target: SIMD2<Double>, snapRadius: Double) -> Result<PlanData, VertexMoveFailure> {
        guard vertexPoints[vertexId] != nil else { return .failure(.vertexNotFound) }
        var result = self
        let attached = walls.filter { $0.startVertex == vertexId || $0.endVertex == vertexId }
        var position = target
        var mergeTarget: String?

        if isFreeEnd(vertexId), let wall = attached.first {
            // 떠 있는 끝: 가까운 꼭짓점·벽이 있으면 붙는다. 없으면 축 자석만 쓴다 (이 벽 자신은 붙을 곳에서 뺀다)
            let otherId = wall.startVertex == vertexId ? wall.endVertex : wall.startVertex
            var probe = self
            probe.walls.removeAll { $0.id == wall.id }
            switch probe.wallEnd(near: target, outward: .zero, snapRadius: snapRadius) {
            case .vertex(let id) where id != otherId:
                mergeTarget = id
            case .wall(let wallId, let point):
                let end = WallEnd.wall(wallId, point)
                guard !result.isDoorInTheWay(end), let id = result.splitWall(wallId, at: point), id != otherId else { break }
                mergeTarget = id
            default:
                break
            }
            if mergeTarget == nil {
                position = magnetized(target, for: vertexId, attached: attached, slideLine: nil, snapRadius: snapRadius)
            }
        } else if let line = straightThroughLine(of: vertexId, attached: attached) {
            // 곧은 벽 중간의 꼭짓점: 그 벽의 선을 따라서만 미끄러진다
            let along = ((target - line.start) * line.direction).sum()
            position = magnetized(line.point(along: along), for: vertexId, attached: attached, slideLine: line, snapRadius: snapRadius)
        } else {
            position = magnetized(target, for: vertexId, attached: attached, slideLine: nil, snapRadius: snapRadius)
        }

        if let mergeTarget, let point = result.vertexPoints[mergeTarget] {
            return result.finishMove(vertexId, to: point, mergingInto: mergeTarget, original: self)
        }
        return result.finishMove(vertexId, to: position, mergingInto: nil, original: self)
    }

    /// 두 벽이 한 직선으로 이어지는 꼭짓점이면 그 직선. 아니면 nil
    private func straightThroughLine(of vertexId: String, attached: [Wall]) -> WallLine? {
        guard attached.count >= 3, let center = vertexPoints[vertexId] else { return nil }
        let pos = vertexPoints
        let directions: [(wall: Wall, direction: SIMD2<Double>)] = attached.compactMap { wall in
            let other = wall.startVertex == vertexId ? wall.endVertex : wall.startVertex
            guard let point = pos[other], Self.length(point - center) > WallMoveRules.eps else { return nil }
            return (wall, (point - center) / Self.length(point - center))
        }
        for i in directions.indices {
            for j in directions.indices where j > i {
                // 방향이 서로 반대면 한 직선
                if (directions[i].direction * directions[j].direction).sum() < -0.999 {
                    let a = center + directions[i].direction
                    let b = center + directions[j].direction
                    return WallLine(start: a, end: b)
                }
            }
        }
        return nil
    }

    /// 점 point를 붙은 벽이 가로·세로가 되는 자리로 맞춘 점. slideLine이 있으면 그 직선 위에서만 맞춘다
    private func magnetized(_ point: SIMD2<Double>, for vertexId: String, attached: [Wall], slideLine: WallLine?, snapRadius: Double) -> SIMD2<Double> {
        let pos = vertexPoints
        var result = point
        var bestX: (value: Double, distance: Double)?
        var bestY: (value: Double, distance: Double)?
        for wall in attached {
            let other = wall.startVertex == vertexId ? wall.endVertex : wall.startVertex
            guard let o = pos[other] else { continue }
            if let slideLine {
                // 직선 위에서, 이 벽이 세로(x = o.x)·가로(y = o.y)가 되는 점
                for candidate in [crossing(of: slideLine, x: o.x), crossing(of: slideLine, y: o.y)].compactMap({ $0 }) {
                    let distance = Self.length(candidate - point)
                    if distance <= snapRadius, distance < (bestX?.distance ?? .infinity) { bestX = (candidate.x, distance); bestY = (candidate.y, distance) }
                }
            } else {
                let dx = abs(point.x - o.x)
                let dy = abs(point.y - o.y)
                if dx <= snapRadius, dx < (bestX?.distance ?? .infinity) { bestX = (o.x, dx) }
                if dy <= snapRadius, dy < (bestY?.distance ?? .infinity) { bestY = (o.y, dy) }
            }
        }
        if let bestX { result.x = bestX.value }
        if let bestY { result.y = bestY.value }
        return result
    }

    /// 직선이 세로선 x = value와 만나는 점. 세로선과 나란하면 nil
    private func crossing(of line: WallLine, x value: Double) -> SIMD2<Double>? {
        let d = line.direction
        guard abs(d.x) > WallMoveRules.eps else { return nil }
        return line.start + d * ((value - line.start.x) / d.x)
    }

    /// 직선이 가로선 y = value와 만나는 점. 가로선과 나란하면 nil
    private func crossing(of line: WallLine, y value: Double) -> SIMD2<Double>? {
        let d = line.direction
        guard abs(d.y) > WallMoveRules.eps else { return nil }
        return line.start + d * ((value - line.start.y) / d.y)
    }

    /// 꼭짓점을 position으로 옮기고, 옮겨도 되는지 검사한다. mergingInto가 있으면 옮긴 뒤 그 꼭짓점에 합친다 (떠 있는 끝을 다른 벽에 붙일 때).
    /// original은 옮기기 전 도면 (스탬프가 잘 있었는지 비교용)
    fileprivate mutating func finishMove(_ vertexId: String, to position: SIMD2<Double>, mergingInto targetId: String?, original: PlanData) -> Result<PlanData, VertexMoveFailure> {
        guard let index = vertices.firstIndex(where: { $0.id == vertexId }) else { return .failure(.vertexNotFound) }
        let attachedIds = walls.filter { $0.startVertex == vertexId || $0.endVertex == vertexId }.map(\.id)
        // 달린 창문·문·콘센트는 벽 길이가 바뀌어도 밖으로 나가지 않아야 한다. 시작 쪽을 옮기면 벽을 따라 잰 거리의 기준이 바뀌어 그만큼 민다
        var shifts: [String: Double] = [:]
        for wallId in attachedIds {
            guard let wall = wall(id: wallId), let line = line(of: wall) else { continue }
            let fixed = wall.startVertex == vertexId ? line.end : line.start
            let newLength = Self.length(position - fixed)
            if !wall.isVirtual, newLength < WallMoveRules.minWallLength { return .failure(.wallTooShort) }
            let shift = wall.startVertex == vertexId ? line.length - newLength : 0
            shifts[wallId] = shift
            let eps = WallMoveRules.eps
            for opening in doorWindows where opening.wallId == wallId {
                let start = opening.centerAlongWall - shift - opening.width / 2
                if start < -eps || start + opening.width > newLength + eps { return .failure(.openingOutsideWall) }
            }
            for fixture in wallFixtures where fixture.wallId == wallId {
                let at = fixture.positionAlongWall - shift
                if at < -eps || at > newLength + eps { return .failure(.openingOutsideWall) }
            }
        }
        for (wallId, shift) in shifts where abs(shift) > 0 {
            for i in doorWindows.indices where doorWindows[i].wallId == wallId { doorWindows[i].centerAlongWall -= shift }
            for i in wallFixtures.indices where wallFixtures[i].wallId == wallId { wallFixtures[i].positionAlongWall -= shift }
        }
        vertices[index].x = position.x
        vertices[index].y = position.y
        var touchedIds = Set(attachedIds)
        if let targetId {
            // 떠 있는 끝이던 꼭짓점을 목표 꼭짓점에 합친다. 이미 같은 두 꼭짓점을 잇는 벽이 있으면 붙일 수 없다
            guard let wallIndex = walls.firstIndex(where: { $0.id == attachedIds.first }) else { return .failure(.vertexNotFound) }
            let otherId = walls[wallIndex].startVertex == vertexId ? walls[wallIndex].endVertex : walls[wallIndex].startVertex
            guard !walls.contains(where: { Set([$0.startVertex, $0.endVertex]) == Set([otherId, targetId]) }) else { return .failure(.crossesWall) }
            if walls[wallIndex].startVertex == vertexId { walls[wallIndex].startVertex = targetId } else { walls[wallIndex].endVertex = targetId }
            vertices.removeAll { $0.id == vertexId }
            touchedIds.insert(walls[wallIndex].id)
        }
        for wall in walls where touchedIds.contains(wall.id) && !wall.isVirtual && crossesWalls(wall) { return .failure(.crossesWall) }
        guard retraceRooms(splitsRooms: true) else { return .failure(.roomsCannotBeRebuilt) }
        cleanUpVirtualWalls()
        addRoomsClosed(by: touchedIds)
        guard original.markers.filter(original.fits).allSatisfy(fits) else { return .failure(.stampInTheWay) }
        refreshRoomLabels()
        return .success(self)
    }
}

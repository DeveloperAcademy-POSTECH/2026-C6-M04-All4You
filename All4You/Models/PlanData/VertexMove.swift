// 꼭짓점 하나를 끌어 옮기는 계산. 꼭짓점에 붙은 벽이 함께 늘고 줄며, 벽이 가로·세로가 되는 자리 근처에서는 딱 붙는다.
// 곧은 벽 중간에 있는 꼭짓점(T자로 붙은 자리 등)은 그 벽의 선을 따라서만 미끄러지고, 다른 벽과 이어지지 않은 벽 끝(떠 있는 끝)은 놓은 자리 가까이 다른 벽·꼭짓점이 있으면 붙는다.
// 거절하지 않는다. 벽 길이가 어떻게 되든 벽에 달린 창문·문·콘센트를 맞추고, 다른 벽을 가로지르면 만나는 자리에서 나누고,
// 겹친 벽은 하나로 합친다 (규칙은 WallEditOutcome.swift 맨 위 설명). 길이가 0이 된 벽은 지우고 두 꼭짓점을 합친다

import Foundation

/// 꼭짓점 옮기기에서 쓰는 값
enum VertexMoveRules {
    /// 떠 있는 끝이 다른 벽의 가운데에 붙는 거리는 꼭짓점에 붙는 거리의 이만큼이다. 넓으면 벽을 가로질러 끌 때 벽에 달라붙어 지나가기 어렵다
    // TEMP: 붙는 거리는 실기기에서 끌어 보고 정함
    static let wallSnapFraction = 0.25
}

extension PlanData {
    /// 꼭짓점 vertexId를 도면 점 target(m)으로 옮긴 새 도면과 자동으로 지운 것. snapRadius(m) 안에서는 가로·세로로 딱 붙이기(축 자석)와 떠 있는 끝 붙이기가 맞춰 준다.
    /// 꼭짓점을 찾지 못하면 도면을 바꾸지 않고 돌려준다
    func movingVertex(_ vertexId: String, to target: SIMD2<Double>, snapRadius: Double) -> WallEditOutcome {
        guard vertexPoints[vertexId] != nil else { return WallEditOutcome(plan: self) }
        var result = self
        var removed: [RemovedItem] = []
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
            case .wall(let wallId, let point) where Self.length(point - target) <= snapRadius * VertexMoveRules.wallSnapFraction:
                guard let id = result.splitWall(wallId, at: point, removed: &removed), id != otherId else { break }
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
            return result.finishMove(vertexId, to: point, mergingInto: mergeTarget, removed: removed)
        }
        return result.finishMove(vertexId, to: position, mergingInto: nil, removed: removed)
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

    /// 꼭짓점을 position으로 옮기고 도면이 성립하게 맞춘다. mergingInto가 있으면 옮긴 뒤 그 꼭짓점에 합친다 (떠 있는 끝을 다른 벽에 붙일 때).
    /// removed는 옮기기 전에 이미 지운 것
    fileprivate mutating func finishMove(_ vertexId: String, to position: SIMD2<Double>, mergingInto targetId: String?, removed earlier: [RemovedItem]) -> WallEditOutcome {
        var removed = earlier
        guard let index = vertices.firstIndex(where: { $0.id == vertexId }) else { return WallEditOutcome(plan: self, removed: removed) }
        let originalVertices = Set(vertices.map(\.id))
        var touched = Set(walls.filter { $0.startVertex == vertexId || $0.endVertex == vertexId }.map(\.id))
        // 벽에 달린 창문·문·콘센트가 원래 있던 자리에 남도록, 옮기기 전 도면 위 자리를 잡아 둔다
        let placesBefore = attachedPlaces(onWalls: touched)
        vertices[index].x = position.x
        vertices[index].y = position.y
        if let targetId { mergeVertex(vertexId, into: targetId) }
        collapseZeroLengthWalls(among: touched, removed: &removed)
        touched = touched.filter { wall(id: $0) != nil }
        fitOpenings(onWalls: touched, placesBefore: placesBefore, removed: &removed)
        splitCrossings(of: touched, removed: &removed)
        // 같은 두 꼭짓점을 잇게 된 벽은 하나로 합치고, 지워진 벽에서 달린 것을 받은 벽을 다시 맞춘다
        let receivers = mergeOverlappingWalls(favoring: touched)
        fitOpenings(onWalls: receivers, placesBefore: [:], removed: &removed)
        removeUnusedVertices(keeping: originalVertices)
        return WallEditOutcome(plan: self, removed: removed)
    }
}

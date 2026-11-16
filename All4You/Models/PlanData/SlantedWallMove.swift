// 비스듬한 벽 한 줄을 평행 이동하는 계산
// 가로·세로 벽은 일직선 줄로 묶어 옮기지만(WallMove), 비스듬한 벽은 그 벽만 옮기고 다른 벽은 움직이지 않는다.
// 벽 양 끝은 붙어 있던 벽의 선을 따라 미끄러진다. 붙은 벽은 늘거나 줄기만 하고 방향·자리는 그대로다.
// 끝에 방향이 다른 벽이 여럿 붙은 모서리(미끄러질 선이 없음)는 그 꼭짓점을 벽과 함께 수직으로 옮긴다. 붙은 벽들이 따라 늘고 기울어진다
// 거절하지 않는다. 벽에 달린 창문·문·콘센트는 맞추고, 다른 벽을 지나면 만나는 자리에서 나눈다 (규칙은 WallEditOutcome.swift 맨 위 설명)

import Foundation

extension PlanData {
    /// 비스듬한 벽(Wall.id)을 수직으로 distance(m)만큼 옮긴 새 도면과 자동으로 지운 것. +는 벽의 왼쪽 면 쪽.
    /// 벽을 찾지 못하면 도면을 바꾸지 않고 돌려준다
    func movingSlantedWall(id: String, by distance: Double) -> WallEditOutcome {
        let eps = WallMoveRules.eps
        guard let wall = wall(id: id), let wallLine = line(of: wall), abs(distance) > eps else { return WallEditOutcome(plan: self) }
        let pos = vertexPoints
        let movedStart = wallLine.start + wallLine.leftNormal * distance
        var result = self
        var removed: [RemovedItem] = []

        // 길이가 늘거나 줄 벽 위의 창문·문·콘센트는 원래 있던 자리에 남아야 하므로, 옮기기 전 도면 위 자리를 적어 둔다
        let touched = walls.filter { $0.id != id && !Set([$0.startVertex, $0.endVertex]).isDisjoint(with: [wall.startVertex, wall.endVertex]) }
        let touchedIds = Set(touched.map(\.id))
        let placeBefore = attachedPlaces(onWalls: touchedIds)

        for (vertexId, original) in [(wall.startVertex, wallLine.start), (wall.endVertex, wallLine.end)] {
            let others = touched.filter { $0.startVertex == vertexId || $0.endVertex == vertexId }
            // 미끄러질 선이 없으면(끝에 방향이 다른 벽이 여럿이거나 나란함) 꼭짓점을 벽과 함께 수직으로 옮긴다
            var newPoint = original + wallLine.leftNormal * distance
            if let slid = slidPoint(of: vertexId, original: original, others: others, positions: pos, wallLine: wallLine, movedStart: movedStart) {
                newPoint = slid
            }
            guard let index = result.vertices.firstIndex(where: { $0.id == vertexId }) else { return WallEditOutcome(plan: self) }
            result.vertices[index].x = newPoint.x
            result.vertices[index].y = newPoint.y
        }

        // 길이 0이 된 벽은 지우고 꼭짓점을 합친다. 늘고 준 벽과 옮긴 벽의 창문·문·콘센트를 맞춘다
        let affected = touchedIds.union([id])
        result.collapseZeroLengthWalls(among: affected, removed: &removed)
        result.fitOpenings(onWalls: touchedIds, placesBefore: placeBefore, removed: &removed)
        // 옮긴 벽 자신에 달린 것은 벽을 따라 함께 가므로(벽 시작점에서 잰 거리로 저장), 벽이 짧아져 밖으로 나가는 경우만 맞춘다
        result.fitOpenings(onWalls: [id], placesBefore: [:], removed: &removed)

        // 다른 벽을 지나면 만나는 자리에서 나누고, 겹쳐 같은 두 꼭짓점을 잇게 된 벽은 하나로 합친다
        result.splitCrossings(of: affected, removed: &removed)
        let receivers = result.mergeOverlappingWalls(favoring: affected)
        result.fitOpenings(onWalls: receivers, placesBefore: [:], removed: &removed)
        result.removeUnusedVertices(keeping: Set(vertices.map(\.id)))
        return WallEditOutcome(plan: result, removed: removed)
    }

    /// 꼭짓점이 붙은 벽의 선을 따라 미끄러져 옮긴 벽의 선과 만나는 점. 붙은 벽이 없거나, 한 직선 위에 있지 않거나, 옮긴 벽과 나란하면 nil
    private func slidPoint(
        of vertexId: String, original: SIMD2<Double>, others: [Wall], positions pos: [String: SIMD2<Double>],
        wallLine: WallLine, movedStart: SIMD2<Double>
    ) -> SIMD2<Double>? {
        let eps = WallMoveRules.eps
        guard !others.isEmpty else { return nil }
        // 붙은 벽들의 먼 쪽 끝. 모두 한 직선 위여야(벽 하나, 또는 꼭짓점을 지나는 일직선 두 조각) 그 선을 따라 미끄러진다
        let farEnds = others.compactMap { pos[$0.startVertex == vertexId ? $0.endVertex : $0.startVertex] }
        guard farEnds.count == others.count, farEnds.count <= 2, let host = farEnds.first.map({ $0 - original }),
              farEnds.allSatisfy({ abs(Self.cross($0 - original, host)) < eps }) else { return nil }
        let denominator = Self.cross(wallLine.direction, host)
        guard abs(denominator) > eps else { return nil }
        return movedStart + wallLine.direction * (Self.cross(original - movedStart, host) / denominator)
    }

    private static func cross(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
        a.x * b.y - a.y * b.x
    }
}

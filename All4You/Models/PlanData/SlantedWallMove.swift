// 비스듬한 벽 한 줄을 평행 이동하는 계산
// 가로·세로 벽은 일직선 줄로 묶어 옮기지만(WallMove), 비스듬한 벽은 그 벽만 옮기고 다른 벽은 제자리에 둔다.
// 벽 양 끝은 붙어 있던 벽의 선을 따라 미끄러진다. 붙은 벽은 늘거나 줄기만 하고 방향·자리는 그대로다

import Foundation

extension PlanData {
    /// 비스듬한 벽(Wall.id)을 수직으로 distance(m)만큼 옮긴 새 도면. +는 벽의 왼쪽 면 쪽.
    /// 옮길 수 없으면 멈춘 이유를 돌려준다
    func movingSlantedWall(id: String, by distance: Double) -> Result<PlanData, SlantedWallBlock> {
        let eps = WallMoveRules.eps
        guard let wall = wall(id: id), let wallLine = line(of: wall) else { return .failure(.brokenPlan) }
        guard abs(distance) > eps else { return .success(self) }
        let pos = vertexPoints
        let movedStart = wallLine.start + wallLine.leftNormal * distance
        var result = self

        // 늘고 줄 벽 위의 창문·문·콘센트는 제자리에 둬야 하므로 옮기기 전 도면 점을 적어 둔다
        let touched = walls.filter { $0.id != id && !Set([$0.startVertex, $0.endVertex]).isDisjoint(with: [wall.startVertex, wall.endVertex]) }
        var placeBefore: [String: SIMD2<Double>] = [:]
        for other in touched {
            guard let otherLine = line(of: other) else { continue }
            for opening in doorWindows where opening.wallId == other.id {
                placeBefore[opening.id] = otherLine.point(along: opening.centerAlongWall)
            }
            for fixture in wallFixtures where fixture.wallId == other.id {
                placeBefore[fixture.id] = otherLine.point(along: fixture.positionAlongWall)
            }
        }

        for (vertexId, original) in [(wall.startVertex, wallLine.start), (wall.endVertex, wallLine.end)] {
            let others = touched.filter { $0.startVertex == vertexId || $0.endVertex == vertexId }
            var newPoint = original + wallLine.leftNormal * distance
            if !others.isEmpty {
                // 붙은 벽들의 먼 쪽 끝. 모두 한 직선 위여야(벽 하나, 또는 꼭짓점을 지나는 일직선 두 조각) 그 선을 따라 미끄러진다
                let farEnds = others.compactMap { pos[$0.startVertex == vertexId ? $0.endVertex : $0.startVertex] }
                guard farEnds.count == others.count, farEnds.count <= 2,
                      let host = farEnds.first.map({ $0 - original }) else { return .failure(.corner) }
                guard farEnds.allSatisfy({ abs(Self.cross($0 - original, host)) < eps }) else { return .failure(.corner) }
                let denominator = Self.cross(wallLine.direction, host)
                guard abs(denominator) > eps else { return .failure(.corner) }
                newPoint = movedStart + wallLine.direction * (Self.cross(original - movedStart, host) / denominator)
                // 붙은 벽은 같은 방향으로 남고 너무 짧아지지 않아야 한다
                for far in farEnds {
                    let after = far - newPoint
                    guard (after * (far - original)).sum() > 0,
                          (after * after).sum().squareRoot() >= WallMoveRules.minWallLength else { return .failure(.tooShort) }
                }
            }
            guard let index = result.vertices.firstIndex(where: { $0.id == vertexId }) else { return .failure(.brokenPlan) }
            result.vertices[index].x = newPoint.x
            result.vertices[index].y = newPoint.y
        }

        // 늘고 준 벽의 창문·문·콘센트를 제자리에 다시 놓고, 벽 밖으로 나가면 옮기지 않는다
        for other in touched {
            guard let otherLine = result.line(of: other) else { return .failure(.brokenPlan) }
            for index in result.doorWindows.indices where result.doorWindows[index].wallId == other.id {
                let opening = result.doorWindows[index]
                guard let place = placeBefore[opening.id] else { continue }
                let along = ((place - otherLine.start) * otherLine.direction).sum()
                guard along - opening.width / 2 >= -eps, along + opening.width / 2 <= otherLine.length + eps else { return .failure(.openings) }
                result.doorWindows[index].centerAlongWall = along
            }
            for index in result.wallFixtures.indices where result.wallFixtures[index].wallId == other.id {
                guard let place = placeBefore[result.wallFixtures[index].id] else { continue }
                let along = ((place - otherLine.start) * otherLine.direction).sum()
                guard along >= -eps, along <= otherLine.length + eps else { return .failure(.openings) }
                result.wallFixtures[index].positionAlongWall = along
            }
        }
        // 옮긴 벽 자체의 창문·문은 벽 시작점 기준이라 함께 가지만, 벽이 짧아져 밖으로 나가면 안 된다
        guard let movedLine = result.line(of: wall), movedLine.length >= WallMoveRules.minWallLength else { return .failure(.tooShort) }
        for opening in result.doorWindows where opening.wallId == id {
            guard opening.centerAlongWall + opening.width / 2 <= movedLine.length + eps else { return .failure(.openings) }
        }

        guard !result.crossesWalls(wall) else { return .failure(.crossing) }
        guard result.retraceRooms() else { return .failure(.brokenPlan) }
        guard markers.filter(fits).allSatisfy(result.fits) else { return .failure(.stamp) }
        result.refreshRoomLabels()
        return .success(result)
    }

    private static func cross(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
        a.x * b.y - a.y * b.x
    }
}

/// 비스듬한 벽이 더 움직이지 못하는 이유
enum SlantedWallBlock: Error {
    /// 끝에 방향이 다른 벽이 여럿 붙어 있어 미끄러질 선이 없음
    case corner
    /// 붙은 벽이나 이 벽이 너무 짧아짐
    case tooShort
    /// 창문·문·콘센트가 벽 밖으로 밀려남
    case openings
    /// 다른 벽과 부딪힘
    case crossing
    /// 사람·발화지점 스탬프에 걸림
    case stamp
    /// 방 경계를 다시 만들 수 없음
    case brokenPlan

    /// 화면 위쪽 캡슐에 보여 줄 문구
    var message: String {
        switch self {
        case .corner: "여러 벽이 만나는 모서리라 옮길 수 없어요"
        case .tooShort: "붙어 있는 벽이 너무 짧아져요"
        case .openings: "붙어 있는 벽의 창문·문이 더 들어가지 않아요"
        case .crossing: "다른 벽과 부딪혀요"
        case .stamp: "스탬프에 걸려요"
        case .brokenPlan: "도면이 깨져서 더 옮길 수 없어요"
        }
    }
}

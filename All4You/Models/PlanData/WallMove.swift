// 가로·세로 벽 옮기기. 가로 벽은 위아래로만, 세로 벽은 좌우로만 옮긴다
//
// 무엇을 옮기나: 벽이 아니라 그 벽의 꼭짓점을 옮긴다. 벽은 꼭짓점 id를 가리키므로 수직으로 붙은 벽은 저절로 늘거나 준다.
// 일직선으로 이어진 벽이 따라오지 않을 때("이 구간만" 고른 경우): 꼭짓점을 그냥 옮기면 이어진 벽이 비스듬해지므로,
//   꼭짓점을 둘로 나누고 그 사이를 새 벽(연결 벽)으로 잇는다. 옛 자리에는 이어진 벽과 뒤쪽 수직 벽이 남고, 새 자리로는 옮기는 벽과 앞쪽 수직 벽이 간다.
// 창문·문·콘센트: 옮기는 벽 위의 것은 벽과 함께 움직인다. 길이가 늘거나 준 벽(옮기는 벽에 수직으로 붙은 벽) 위의 것은 원래 있던 자리에 남고,
//   벽 끝에 걸리면 안쪽으로 밀리고, 그래도 안 들어가면 폭이 줄거나 지워진다 (자세한 규칙은 WallEditOutcome.swift 맨 위 설명).
// 멈추지 않는다: 다른 벽에 닿거나 지나가도, 붙은 벽이 짧아져도 거절하지 않는다. 만나는 자리에서 벽을 나누고, 붙은 벽이 길이 0이 되면 그 벽을 지우고 꼭짓점을 합친다.
// 적용: movingWalls(_:by:)는 늘 "끌기 시작할 때 도면 + 이동량"으로 계산하므로 끄는 중에 왔다 갔다 해도 흔적이 남지 않는다

import Foundation

/// 벽이 놓인 방향
enum WallAxis: Equatable {
    case horizontal, vertical
    /// 벽을 따라가는 좌표 번호 (0 = x, 1 = y)
    var along: Int { self == .horizontal ? 0 : 1 }
    /// 벽이 움직이는 좌표 번호
    var across: Int { self == .horizontal ? 1 : 0 }
}

/// 벽 옮기기에서 쓰는 값 (m)
enum WallMoveRules {
    /// 좌표 비교 오차
    static let eps = 1e-6
    // TEMP: openingMargin·snapDistance는 디자인·실측 확인 전이라 임시로 정한 값
    /// 창문·문과 벽 끝 사이, 창문·문끼리 사이 여백
    static let openingMargin = 0.1
    /// 이만큼 안으로 끌면 움직이지 않은 것으로, 붙은 벽이 길이 0이 되는 자리 이만큼 앞이면 그 자리에 붙인다
    static let snapDistance = 0.05
}

/// 함께 움직일 벽 묶음. 화면 상태라 저장하지 않는다
struct WallSelection: Equatable {
    var wallIds: Set<String>
    var axis: WallAxis
    /// true = 일직선으로 이어진 줄 전체, false = 한 구간만
    var isWholeLine: Bool
}

// 고르기
extension PlanData {
    /// 꼭짓점 id → 도면 좌표 (m)
    var vertexPoints: [String: SIMD2<Double>] {
        Dictionary(uniqueKeysWithValues: vertices.map { ($0.id, SIMD2($0.x, $0.y)) })
    }

    /// 가로·세로 벽이면 그 방향. 비스듬하거나 길이 0이면 nil
    func axis(of wall: Wall, _ pos: [String: SIMD2<Double>]) -> WallAxis? {
        guard let a = pos[wall.startVertex], let b = pos[wall.endVertex] else { return nil }
        let eps = WallMoveRules.eps
        if abs(a.y - b.y) < eps, abs(a.x - b.x) > eps { return .horizontal }
        if abs(a.x - b.x) < eps, abs(a.y - b.y) > eps { return .vertical }
        return nil
    }

    /// 벽 한 구간만. 비스듬한 벽이면 nil
    func wallSegment(_ id: String) -> WallSelection? {
        guard let wall = wall(id: id), let axis = axis(of: wall, vertexPoints) else { return nil }
        return WallSelection(wallIds: [id], axis: axis, isWholeLine: false)
    }

    /// 그 벽과 일직선으로 이어진 벽 전체
    func wallLine(containing id: String) -> WallSelection? {
        guard var selection = wallSegment(id) else { return nil }
        let pos = vertexPoints
        var stack = [id]
        while let current = stack.popLast(), let wall = wall(id: current) {
            for other in walls where !selection.wallIds.contains(other.id) && axis(of: other, pos) == selection.axis {
                let shares = [other.startVertex, other.endVertex].contains { $0 == wall.startVertex || $0 == wall.endVertex }
                if shares {
                    selection.wallIds.insert(other.id)
                    stack.append(other.id)
                }
            }
        }
        selection.isWholeLine = true
        return selection
    }

    /// 고른 벽들의 꼭짓점
    func movedVertices(_ selection: WallSelection) -> Set<String> {
        var result = Set<String>()
        for wall in walls where selection.wallIds.contains(wall.id) {
            result.insert(wall.startVertex)
            result.insert(wall.endVertex)
        }
        return result
    }
}

// 이동량 맞추기
extension PlanData {
    /// 끈 거리 raw(m)를 실제 이동량으로. 아주 조금 끈 것은 움직이지 않은 것으로 보고, 붙은 벽이 길이 0이 되는 자리 가까이면 그 자리에 붙인다 (두 꼭짓점이 합쳐진다)
    func snappedMoveDistance(for selection: WallSelection, raw: Double) -> Double {
        let magnitude = abs(raw)
        guard magnitude >= WallMoveRules.snapDistance else { return 0 }
        let sign: Double = raw < 0 ? -1 : 1
        let pos = vertexPoints
        let moved = movedVertices(selection)
        let across = selection.axis.across
        for wall in walls where !selection.wallIds.contains(wall.id) {
            let startMoves = moved.contains(wall.startVertex)
            let endMoves = moved.contains(wall.endVertex)
            guard startMoves != endMoves,
                  let here = pos[startMoves ? wall.startVertex : wall.endVertex],
                  let far = pos[startMoves ? wall.endVertex : wall.startVertex],
                  axis(of: wall, pos) != selection.axis else { continue }
            let distance = sign * (far[across] - here[across])
            if distance > WallMoveRules.eps, abs(magnitude - distance) < WallMoveRules.snapDistance { return sign * distance }
        }
        return raw
    }
}

// 적용
extension PlanData {
    /// 이 도면에서 고른 벽들을 delta(m)만큼 옮긴 새 도면과 자동으로 지운 것. 거절하지 않는다
    func movingWalls(_ selection: WallSelection, by delta: Double) -> WallEditOutcome {
        let eps = WallMoveRules.eps
        guard abs(delta) > eps else { return WallEditOutcome(plan: self) }
        var result = self
        var removed: [RemovedItem] = []
        let across = selection.axis.across
        let moved = movedVertices(selection)
        let sign: Double = delta > 0 ? 1 : -1
        var pos = vertexPoints

        // 길이가 늘거나 준 벽 위의 창문·문·콘센트는 원래 있던 자리에 남아야 하므로, 옮기기 전 자리를 적어 둔다
        let stretched = Set(walls
            .filter { !selection.wallIds.contains($0.id) && (moved.contains($0.startVertex) || moved.contains($0.endVertex)) }
            .map(\.id))
        let placeBefore = attachedPlaces(onWalls: stretched)
        // 콘센트가 바라보던 쪽. 다른 벽으로 옮겨 붙을 때 같은 쪽 면을 고른다
        var facingBefore: [String: SIMD2<Double>] = [:]
        for fixture in wallFixtures where stretched.contains(fixture.wallId) {
            guard let wall = wall(id: fixture.wallId), let line = line(of: wall) else { continue }
            facingBefore[fixture.id] = fixture.face == .left ? line.leftNormal : -line.leftNormal
        }

        for vertex in moved.sorted() {
            guard let origin = pos[vertex] else { return WallEditOutcome(plan: self) }
            let incident = result.walls.indices.filter {
                let wall = result.walls[$0]
                return !selection.wallIds.contains(wall.id) && (wall.startVertex == vertex || wall.endVertex == vertex)
            }
            let collinear = incident.filter { result.axis(of: result.walls[$0], pos) == selection.axis }
            if let firstCollinear = collinear.first {
                // 일직선으로 이어진 벽이 남는다 → 꼭짓점을 나누고 연결 벽으로 잇는다
                let behind = incident.filter { index in
                    let wall = result.walls[index]
                    guard result.axis(of: wall, pos) != selection.axis,
                          let far = pos[wall.startVertex == vertex ? wall.endVertex : wall.startVertex] else { return false }
                    return sign * (far[across] - origin[across]) < 0
                }
                let split = Vertex(id: UUID().uuidString, x: origin.x, y: origin.y)
                result.vertices.append(split)
                pos[split.id] = origin
                for index in collinear + behind {
                    if result.walls[index].startVertex == vertex { result.walls[index].startVertex = split.id }
                    if result.walls[index].endVertex == vertex { result.walls[index].endVertex = split.id }
                }
                let template = result.walls[firstCollinear]
                result.walls.append(Wall(
                    id: UUID().uuidString, startVertex: split.id, endVertex: vertex,
                    thickness: template.thickness, height: template.height
                ))
            }
            pos[vertex]![across] += delta
        }
        for index in result.vertices.indices {
            guard let point = pos[result.vertices[index].id] else { continue }
            result.vertices[index].x = point.x
            result.vertices[index].y = point.y
        }

        // 길이 0이 된 벽을 없애고 양 끝 꼭짓점을 합친다. 그 벽에 달린 창문·문·콘센트도 함께 지우고 removed에 기록한다
        result.collapseZeroLengthWalls(among: Set(result.walls.map(\.id)), removed: &removed)

        // 벽이 줄어 콘센트 자리가 벽 밖으로 나갔으면, 그 자리를 덮는 일직선 옆 벽으로 옮겨 붙인다
        result.hopFixtures(placeBefore: placeBefore, facingBefore: facingBefore)

        // 길이가 늘거나 준 벽 위의 창문·문·콘센트를 맞춘다: 원래 자리 → 밀기 → 폭 줄이기 → 지우기
        result.fitOpenings(onWalls: stretched, placesBefore: placeBefore, removed: &removed)

        // 다른 벽과 가로지르거나 닿는 자리는 나누고, 겹쳐 같은 두 꼭짓점을 잇게 된 벽은 하나로 합친다
        let touched = Set(result.walls.filter {
            selection.wallIds.contains($0.id) || moved.contains($0.startVertex) || moved.contains($0.endVertex)
        }.map(\.id))
        result.splitCrossings(of: touched, removed: &removed)
        let receivers = result.mergeOverlappingWalls(favoring: touched)
        result.fitOpenings(onWalls: receivers, placesBefore: [:], removed: &removed)
        result.removeUnusedVertices(keeping: Set(vertices.map(\.id)))
        return WallEditOutcome(plan: result, removed: removed)
    }

    /// 벽이 줄어 벽 밖으로 나간 콘센트를, 그 자리를 덮는 일직선 옆 벽으로 옮겨 붙인다. 같은 쪽 면을 고른다
    private mutating func hopFixtures(placeBefore: [String: SIMD2<Double>], facingBefore: [String: SIMD2<Double>]) {
        let eps = WallMoveRules.eps
        for index in wallFixtures.indices {
            let fixture = wallFixtures[index]
            guard let place = placeBefore[fixture.id], let facing = facingBefore[fixture.id],
                  let owner = wall(id: fixture.wallId), let ownerLine = line(of: owner) else { continue }
            let along = ((place - ownerLine.start) * ownerLine.direction).sum()
            guard along < -eps || along > ownerLine.length + eps else { continue }
            for wall in walls where wall.id != owner.id {
                guard let line = line(of: wall), line.length > eps else { continue }
                let offset = place - line.start
                let newAlong = (offset * line.direction).sum()
                guard abs((offset * line.leftNormal).sum()) < eps,
                      newAlong >= -eps, newAlong <= line.length + eps else { continue }
                wallFixtures[index].wallId = wall.id
                wallFixtures[index].positionAlongWall = min(max(newAlong, 0), line.length)
                wallFixtures[index].face = (facing * line.leftNormal).sum() > 0 ? .left : .right
                break
            }
        }
    }
}

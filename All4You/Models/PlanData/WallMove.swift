// 가로·세로 벽 옮기기. 가로 벽은 위아래로만, 세로 벽은 좌우로만 옮긴다
//
// 무엇을 옮기나: 벽이 아니라 그 벽의 꼭짓점을 옮긴다. 벽은 꼭짓점 id를 가리키므로 수직으로 붙은 벽은 저절로 늘거나 준다.
// 일직선으로 이어진 벽이 따라오지 않을 때("이 구간만" 고른 경우): 꼭짓점을 그냥 옮기면 이어진 벽이 비스듬해지므로,
//   꼭짓점을 둘로 나누고 그 사이를 새 벽(연결 벽)으로 잇는다. 옛 자리에는 이어진 벽과 뒤쪽 수직 벽이 남고, 새 자리로는 옮기는 벽과 앞쪽 수직 벽이 간다.
// 방 경계: 벽을 다시 이은 뒤 방 경계를 다시 만든다(RoomTracer). 이름 자리가 방 밖으로 나가면 방 안으로 옮긴다.
// 창문·문·콘센트: 옮기는 벽 위의 것은 함께 움직인다. 늘고 주는 벽 위의 것은 제자리에 있다가, 벽 끝에 걸리면 밀린다.
// 이동 범위: moveLimits()가 미리 계산한다. 다른 벽과 부딪히거나 벽이 너무 짧아지면 거기서 멈춘다.
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
    /// TEMP: 디자인·실측 확인 전이라 임시로 정한 값
    /// 줄어드는 벽의 가장 짧은 길이
    static let minWallLength = 0.3
    /// 마주 보는 벽과의 가장 좁은 간격
    static let minClearance = 0.3
    /// 창문·문과 벽 끝 사이 여백
    static let openingMargin = 0.1
    /// 이만큼 안으로 끌면 움직이지 않은 것으로, 합쳐지는 자리 이만큼 앞이면 그 자리에 붙인다
    static let snapDistance = 0.05
}

/// 함께 움직일 벽 묶음. 화면 상태라 저장하지 않는다
struct WallSelection: Equatable {
    var wallIds: Set<String>
    var axis: WallAxis
    /// true = 일직선으로 이어진 줄 전체, false = 한 구간만
    var isWholeLine: Bool
}

/// 한 방향으로 갈 수 있는 거리와 멈추는 이유
struct MoveLimit: Equatable {
    var distance: Double
    var reason: String
    /// 앞쪽 벽이 길이 0이 되며 다른 벽과 합쳐지는 거리. 합쳐도 괜찮을 때만 값이 있다
    var mergeDistance: Double?
}

struct MoveLimits: Equatable {
    var negative: MoveLimit
    var positive: MoveLimit
    func limit(sign: Double) -> MoveLimit { sign < 0 ? negative : positive }

    /// 끈 거리 raw(m)를 범위에 맞춘 실제 이동량과, 범위 끝에 막혔으면 그 이유
    func resolve(_ raw: Double) -> (delta: Double, blockedBy: String?) {
        let sign: Double = raw < 0 ? -1 : 1
        let limit = limit(sign: sign)
        let magnitude = abs(raw)
        if magnitude > limit.distance + WallMoveRules.eps {
            if let merge = limit.mergeDistance, magnitude >= merge - WallMoveRules.snapDistance {
                return (sign * merge, nil)
            }
            return (sign * limit.distance, limit.reason)
        }
        if magnitude < WallMoveRules.snapDistance { return (0, nil) }
        return (raw, nil)
    }
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

    /// 고른 줄의 지금 좌표 (움직이는 축)
    func coordinate(of selection: WallSelection) -> Double {
        let pos = vertexPoints
        guard let vertex = movedVertices(selection).first, let point = pos[vertex] else { return 0 }
        return point[selection.axis.across]
    }
}

// 이동 범위
extension PlanData {
    /// 이동을 막는 조건 하나
    private struct MoveConstraint {
        var allowed: Double
        var reason: String
        /// 앞쪽 수직 벽: 길이 0이 되면 합쳐질 수 있는 후보
        var collapse: (length: Double, far: String, hasAttachments: Bool)?
        /// 부딪히는 벽의 거리와 양 끝 (합치는 자리에 원래 붙어 있던 벽은 부딪힘으로 치지 않으려고)
        var obstacle: (distance: Double, a: String, b: String)?
    }

    func moveLimits(_ selection: WallSelection) -> MoveLimits {
        MoveLimits(negative: moveLimit(selection, sign: -1), positive: moveLimit(selection, sign: 1))
    }

    private func moveLimit(_ selection: WallSelection, sign: Double) -> MoveLimit {
        let eps = WallMoveRules.eps
        let pos = vertexPoints
        let moved = movedVertices(selection)
        let across = selection.axis.across
        let along = selection.axis.along
        let start = coordinate(of: selection)
        let spans = moved.compactMap { pos[$0]?[along] }
        let low = spans.min() ?? 0
        let high = spans.max() ?? 0

        var constraints = [MoveConstraint(allowed: .infinity, reason: "")]
        for wall in walls where !selection.wallIds.contains(wall.id) {
            guard let a = pos[wall.startVertex], let b = pos[wall.endVertex], let wallAxis = axis(of: wall, pos) else { continue }
            if wallAxis == selection.axis {
                // 마주 보는 평행한 벽: 벽을 따라간 범위가 겹치면 부딪힌다
                let distance = sign * (a[across] - start)
                let wallLow = min(a[along], b[along])
                let wallHigh = max(a[along], b[along])
                if distance > eps, wallHigh >= low - eps, wallLow <= high + eps {
                    constraints.append(MoveConstraint(
                        allowed: distance - WallMoveRules.minClearance, reason: Copy.tooClose,
                        obstacle: (distance, wall.startVertex, wall.endVertex)
                    ))
                }
            } else {
                let startMoves = moved.contains(wall.startVertex)
                let endMoves = moved.contains(wall.endVertex)
                if startMoves || endMoves {
                    // 붙어 있는 수직 벽: 앞쪽이면 줄어든다
                    let here = startMoves ? a : b
                    let far = startMoves ? b : a
                    let distance = sign * (far[across] - here[across])
                    guard distance > eps else { continue }
                    let openings = doorWindows.filter { $0.wallId == wall.id }
                    let need = openings.isEmpty ? 0
                        : openings.map(\.width).reduce(0, +) + WallMoveRules.openingMargin * Double(openings.count + 1)
                    let hasAttachments = !openings.isEmpty || wallFixtures.contains { $0.wallId == wall.id }
                    constraints.append(MoveConstraint(
                        allowed: distance - max(WallMoveRules.minWallLength, need),
                        reason: need > WallMoveRules.minWallLength ? Copy.openingsDoNotFit : Copy.tooShort,
                        collapse: (distance, startMoves ? wall.endVertex : wall.startVertex, hasAttachments)
                    ))
                } else if a[along] >= low - eps, a[along] <= high + eps {
                    // 붙어 있지 않은 수직 벽: 가까운 끝에 부딪힌다
                    let near = sign > 0 ? min(a[across], b[across]) - start : start - max(a[across], b[across])
                    if near > eps {
                        constraints.append(MoveConstraint(
                            allowed: near - WallMoveRules.minClearance, reason: Copy.tooClose,
                            obstacle: (near, wall.startVertex, wall.endVertex)
                        ))
                    }
                }
            }
        }

        let tightest = constraints.min { $0.allowed < $1.allowed }!
        var result = MoveLimit(distance: max(0, tightest.allowed), reason: tightest.reason)

        // 합치기 후보: 가장 짧은 앞쪽 수직 벽이 길이 0이 되는 거리
        let candidates = constraints.compactMap(\.collapse)
        if let length = candidates.map(\.length).min() {
            let collapsing = candidates.filter { abs($0.length - length) < eps }
            let farEnds = Set(collapsing.map(\.far))
            let others = constraints.filter { constraint in
                if let collapse = constraint.collapse, abs(collapse.length - length) < eps { return false }
                if let obstacle = constraint.obstacle, abs(obstacle.distance - length) < eps,
                   farEnds.contains(obstacle.a) || farEnds.contains(obstacle.b) { return false }
                return true
            }
            let free = others.map(\.allowed).min() ?? .infinity
            if !collapsing.contains(where: \.hasAttachments), free >= length - eps,
               movingWalls(selection, by: sign * length) != nil {
                result.mergeDistance = length
            }
        }
        return result
    }
}

// 적용
extension PlanData {
    /// 이 도면에서 고른 벽들을 delta(m)만큼 옮긴 새 도면. 도면이 깨지면 nil (부르는 쪽은 마지막으로 맞는 도면을 그대로 둔다)
    func movingWalls(_ selection: WallSelection, by delta: Double) -> PlanData? {
        let eps = WallMoveRules.eps
        guard abs(delta) > eps else { return self }
        var result = self
        let across = selection.axis.across
        let moved = movedVertices(selection)
        let sign: Double = delta > 0 ? 1 : -1
        var pos = vertexPoints

        // 늘고 주는 벽 위의 창문·문·콘센트는 제자리에 있어야 하므로 옮기기 전 자리를 적어 둔다
        let stretched = Set(walls
            .filter { !selection.wallIds.contains($0.id) && (moved.contains($0.startVertex) || moved.contains($0.endVertex)) }
            .map(\.id))
        var placeBefore: [String: SIMD2<Double>] = [:]
        // 콘센트가 바라보던 쪽. 다른 벽으로 옮겨 붙을 때 같은 쪽 면을 고른다
        var facingBefore: [String: SIMD2<Double>] = [:]
        for opening in doorWindows where stretched.contains(opening.wallId) {
            guard let wall = wall(id: opening.wallId), let line = line(of: wall) else { continue }
            placeBefore[opening.id] = line.point(along: opening.centerAlongWall)
        }
        for fixture in wallFixtures where stretched.contains(fixture.wallId) {
            guard let wall = wall(id: fixture.wallId), let line = line(of: wall) else { continue }
            placeBefore[fixture.id] = line.point(along: fixture.positionAlongWall)
            facingBefore[fixture.id] = fixture.face == .left ? line.leftNormal : -line.leftNormal
        }

        for vertex in moved.sorted() {
            guard let origin = pos[vertex] else { return nil }
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
                    thickness: template.thickness, height: template.height, isVirtual: template.isVirtual
                ))
            }
            pos[vertex]![across] += delta
        }
        for index in result.vertices.indices {
            guard let point = pos[result.vertices[index].id] else { continue }
            result.vertices[index].x = point.x
            result.vertices[index].y = point.y
        }

        // 길이 0이 된 벽을 없애고 양 끝 꼭짓점을 합친다. 무언가 붙어 있는 벽이면 실패
        for wall in result.walls {
            guard let a = pos[wall.startVertex], let b = pos[wall.endVertex] else { return nil }
            let delta = b - a
            guard (delta * delta).sum().squareRoot() < eps else { continue }
            if result.doorWindows.contains(where: { $0.wallId == wall.id })
                || result.wallFixtures.contains(where: { $0.wallId == wall.id }) { return nil }
            let keep = moved.contains(wall.startVertex) ? wall.endVertex : wall.startVertex
            let gone = keep == wall.startVertex ? wall.endVertex : wall.startVertex
            result.walls.removeAll { $0.id == wall.id }
            result.vertices.removeAll { $0.id == gone }
            for index in result.walls.indices {
                if result.walls[index].startVertex == gone { result.walls[index].startVertex = keep }
                if result.walls[index].endVertex == gone { result.walls[index].endVertex = keep }
            }
        }

        // 늘고 준 벽 위의 것: 제자리 유지 → 벽 끝에 걸리면 밀기 → 그래도 안 들어가면 실패
        for wallId in stretched {
            guard let wall = result.wall(id: wallId), let line = result.line(of: wall) else { continue }
            let indices = result.doorWindows.indices
                .filter { result.doorWindows[$0].wallId == wallId }
                .sorted { result.doorWindows[$0].centerAlongWall < result.doorWindows[$1].centerAlongWall }
            var starts = indices.map { index -> Double in
                let opening = result.doorWindows[index]
                let along = placeBefore[opening.id].map { (($0 - line.start) * line.direction).sum() } ?? opening.centerAlongWall
                return along - opening.width / 2
            }
            var floor = WallMoveRules.openingMargin
            for k in starts.indices {
                starts[k] = max(starts[k], floor)
                floor = starts[k] + result.doorWindows[indices[k]].width + WallMoveRules.openingMargin
            }
            var ceiling = line.length - WallMoveRules.openingMargin
            for k in starts.indices.reversed() {
                starts[k] = min(starts[k], ceiling - result.doorWindows[indices[k]].width)
                ceiling = starts[k] - WallMoveRules.openingMargin
            }
            if let first = starts.first, first < WallMoveRules.openingMargin - eps { return nil }
            for k in starts.indices {
                result.doorWindows[indices[k]].centerAlongWall = starts[k] + result.doorWindows[indices[k]].width / 2
            }
            for index in result.wallFixtures.indices where result.wallFixtures[index].wallId == wallId {
                let fixture = result.wallFixtures[index]
                let along = placeBefore[fixture.id].map { (($0 - line.start) * line.direction).sum() } ?? fixture.positionAlongWall
                result.wallFixtures[index].positionAlongWall = min(max(along, 0), line.length)
            }
        }
        // 벽이 줄어 콘센트 자리가 벽 밖으로 나갔으면, 그 자리를 덮는 일직선 옆 벽으로 옮겨 붙인다
        for index in result.wallFixtures.indices {
            let fixture = result.wallFixtures[index]
            guard let place = placeBefore[fixture.id], let facing = facingBefore[fixture.id],
                  let owner = result.wall(id: fixture.wallId), let ownerLine = result.line(of: owner) else { continue }
            let along = ((place - ownerLine.start) * ownerLine.direction).sum()
            guard along < -eps || along > ownerLine.length + eps else { continue }
            for wall in result.walls where !wall.isVirtual && wall.id != owner.id {
                guard let line = result.line(of: wall), line.length > eps else { continue }
                let offset = place - line.start
                let newAlong = (offset * line.direction).sum()
                guard abs((offset * line.leftNormal).sum()) < eps,
                      newAlong >= -eps, newAlong <= line.length + eps else { continue }
                result.wallFixtures[index].wallId = wall.id
                result.wallFixtures[index].positionAlongWall = min(max(newAlong, 0), line.length)
                result.wallFixtures[index].face = (facing * line.leftNormal).sum() > 0 ? .left : .right
                break
            }
        }

        guard result.hasNoCrossingWalls, result.retraceRooms() else { return nil }
        // 방 안에 잘 있던 사람·발화지점이 벽에 걸리거나 방 밖이 되는 자리로는 옮기지 않는다
        guard markers.filter(fits).allSatisfy(result.fits) else { return nil }
        result.refreshRoomLabels()
        return result
    }
}

// 멈추는 이유 문구
private enum Copy {
    static let tooClose = "다른 벽과 너무 가까워요"
    static let tooShort = "붙어 있는 벽이 너무 짧아져요"
    static let openingsDoNotFit = "붙어 있는 벽의 창문·문이 더 들어가지 않아요"
}

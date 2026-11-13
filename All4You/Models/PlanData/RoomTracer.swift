// 벽 연결에서 방 경계(Room.boundary)를 다시 만들고, 방 밖으로 나간 이름 자리를 방 안으로 옮긴다
//
// 면 따라 돌기: 벽 하나를 방향이 반대인 두 "면"으로 본다. 면을 따라가다 꼭짓점에 닿으면 가장 오른쪽으로 꺾는다.
// 이렇게 돌면 방은 화면에서 시계 방향(넓이 +)으로, 건물 바깥은 반시계 방향(넓이 −)으로 한 바퀴 돈다.
// 방 이름 잇기: 옮기기 전에 어떤 면이 어느 방이었는지 기억해 두고, 다시 돈 고리에 그 면이 있으면 같은 방으로 본다.
// 벽 이동은 방을 새로 만들거나 없애지 않으므로 고리와 방은 하나씩 짝이 맞아야 한다. 안 맞으면 실패

import Foundation

extension PlanData {
    /// 방 경계를 다시 만든다. 고리와 방의 짝이 맞지 않으면 바꾸지 않고 false.
    /// splitsRooms가 true면 새로 그린 벽이 방 하나를 여러 고리로 나눈 것을 허락한다.
    /// 이름 자리가 든 고리가 원래 방을 잇고, 나머지 고리는 새 방이 된다.
    /// mergesRooms가 true면 벽을 지워 여러 방이 한 고리가 된 것을 허락한다. 목록에서 앞선 방이 남고 나머지 방은 빠진다
    mutating func retraceRooms(splitsRooms: Bool = false, mergesRooms: Bool = false) -> Bool {
        guard let loops = faceLoops() else { return false }

        var roomOfSide: [String: String] = [:]
        for room in rooms { for edge in room.boundary { roomOfSide["\(edge.wallId)/\(edge.forward)"] = room.id } }

        var loopsOfRoom: [String: [[RoomEdge]]] = [:]
        var mergedRoomIds = Set<String>()
        var outerCount = 0
        for (loop, area) in loops {
            let names = Set(loop.compactMap { roomOfSide["\($0.wallId)/\($0.forward)"] })
            if area > WallMoveRules.eps {
                // 방이 아닌 닫힌 고리(이름이 없는 칸)는 그대로 둔다
                guard names.count <= 1 || mergesRooms else { return false }
                guard let name = rooms.first(where: { names.contains($0.id) })?.id else { continue }
                mergedRoomIds.formUnion(names.subtracting([name]))
                loopsOfRoom[name, default: []].append(loop)
            } else {
                guard names.isEmpty else { return false }
                outerCount += 1
            }
        }
        // 실패하면 도면을 바꾸지 않아야 하므로, 합쳐져 빠질 방은 끝에서 한 번에 뺀다
        let keptRooms = rooms.filter { !mergedRoomIds.contains($0.id) }
        guard outerCount >= 1, loopsOfRoom.count == keptRooms.count else { return false }
        var boundaries: [String: [RoomEdge]] = [:]
        var newRooms: [Room] = []
        for room in keptRooms {
            guard var loops = loopsOfRoom[room.id] else { return false }
            if loops.count > 1 {
                guard splitsRooms else { return false }
                // 이름 자리가 든 고리가 원래 방을 잇는다. 그런 고리가 없으면 가장 넓은 고리
                let label = SIMD2(room.labelX, room.labelY)
                let keep = loops.firstIndex { Self.polygon(points(of: $0), contains: label) }
                    ?? loops.indices.max { Self.signedArea(points(of: loops[$0])) < Self.signedArea(points(of: loops[$1])) }!
                boundaries[room.id] = loops.remove(at: keep)
                for loop in loops {
                    // 이름 자리는 아래 refreshRoomLabels가 방 안으로 옮긴다
                    newRooms.append(Room(id: UUID().uuidString, name: RoomCopy.newRoomName, boundary: loop, labelX: .infinity, labelY: .infinity))
                }
            } else {
                boundaries[room.id] = loops[0]
            }
        }
        var retraced = keptRooms
        for index in retraced.indices {
            guard var boundary = boundaries[retraced[index].id] else { return false }
            // 시작 벽이 그대로 있으면 시작을 맞춰 둔다
            if let first = retraced[index].boundary.first, let at = boundary.firstIndex(of: first) {
                boundary = Array(boundary[at...] + boundary[..<at])
            }
            retraced[index].boundary = boundary
        }
        rooms = retraced + newRooms
        return true
    }

    /// 방 밖에서 새로 그린 벽(wallIds)이 닫은 칸마다 "새 공간" 방을 만든다. 새 벽의 면이 든 고리만 보므로, 이름을 지워 둔 기존 이름 없는 칸은 건드리지 않는다.
    /// 이름 자리는 아직 없어, 이어서 부르는 refreshRoomLabels가 방 가운데에 놓는다
    mutating func addRoomsClosed(by wallIds: Set<String>) {
        guard let loops = faceLoops() else { return }
        let takenSides = Set(rooms.flatMap(\.boundary).map { "\($0.wallId)/\($0.forward)" })
        for loop in loops where loop.area > WallMoveRules.eps
            && loop.edges.contains(where: { wallIds.contains($0.wallId) })
            && !loop.edges.contains(where: { takenSides.contains("\($0.wallId)/\($0.forward)") }) {
            rooms.append(Room(id: UUID().uuidString, name: RoomCopy.newRoomName, boundary: loop.edges, labelX: .infinity, labelY: .infinity))
        }
    }

    /// 벽 연결을 면 따라 돌아 닫힌 고리를 모두 찾는다. 방은 넓이 +, 건물 바깥은 넓이 −. 꼭짓점을 못 찾는 벽이 있으면 nil
    func faceLoops() -> [(edges: [RoomEdge], area: Double)]? {
        let pos = vertexPoints
        // 한쪽 끝이 어디에도 이어지지 않은 벽(따로 세운 벽 등)은 방을 나누지 않으므로 빼고 돈다
        let looped = loopedWalls()
        struct Side { let wallId: String; let forward: Bool; let from: String; let to: String; let angle: Double }
        var sides: [Side] = []
        for wall in walls where looped.contains(wall.id) {
            guard let a = pos[wall.startVertex], let b = pos[wall.endVertex] else { return nil }
            sides.append(Side(wallId: wall.id, forward: true, from: wall.startVertex, to: wall.endVertex, angle: atan2(b.y - a.y, b.x - a.x)))
            sides.append(Side(wallId: wall.id, forward: false, from: wall.endVertex, to: wall.startVertex, angle: atan2(a.y - b.y, a.x - b.x)))
        }
        // 꼭짓점별로 나가는 면을 각도순으로 (y가 아래로 커지므로 각도가 커지는 쪽이 화면 시계 방향)
        var outgoing: [String: [Int]] = [:]
        for index in sides.indices { outgoing[sides[index].from, default: []].append(index) }
        for key in outgoing.keys { outgoing[key]!.sort { sides[$0].angle < sides[$1].angle } }
        // 면 i의 반대쪽 면은 i ^ 1 (같은 벽의 두 면을 나란히 넣었으므로)
        func next(_ index: Int) -> Int {
            let list = outgoing[sides[index].to]!
            let twinAt = list.firstIndex(of: index ^ 1)!
            return list[(twinAt - 1 + list.count) % list.count]
        }

        var visited = Set<Int>()
        var loops: [(edges: [RoomEdge], area: Double)] = []
        for start in sides.indices where !visited.contains(start) {
            var loop: [Int] = []
            var current = start
            repeat {
                visited.insert(current)
                loop.append(current)
                current = next(current)
            } while current != start
            loops.append((
                edges: loop.map { RoomEdge(wallId: sides[$0].wallId, forward: sides[$0].forward) },
                area: Self.signedArea(loop.map { pos[sides[$0].from]! })
            ))
        }
        return loops
    }

    /// 벽으로 닫힌 칸들의 꼭짓점 점들. 방(Room)과, 공간 라벨이 없는 닫힌 칸을 모두 포함한다. 가구처럼 방이 아니어도 놓을 수 있는 것이 칸 안인지 볼 때 쓴다
    func closedCellPolygons() -> [[SIMD2<Double>]] {
        var polygons = rooms.map { polygon(of: $0) }
        for loop in faceLoops() ?? [] where loop.area > WallMoveRules.eps {
            polygons.append(points(of: loop.edges))
        }
        return polygons
    }

    /// 방 경계 벽들을 도는 방향 쪽 시작점으로 바꾼 점들
    private func points(of boundary: [RoomEdge]) -> [SIMD2<Double>] {
        polygon(of: Room(id: "", name: "", boundary: boundary, labelX: 0, labelY: 0))
    }

    /// 이름 자리가 방 밖으로 나간 방은, 방을 x·y 좌표로 격자처럼 잘라 방 안에서 가장 넓은 칸의 가운데로 옮긴다
    mutating func refreshRoomLabels() {
        for index in rooms.indices {
            // 방을 나눠 새로 생긴 방은 이름 자리가 아직 없으므로 방 가운데에 놓는다
            guard rooms[index].labelX.isFinite else {
                centerRoomLabel(id: rooms[index].id)
                continue
            }
            let polygon = polygon(of: rooms[index])
            let label = SIMD2(rooms[index].labelX, rooms[index].labelY)
            guard room(containing: label)?.id != rooms[index].id,
                  let center = Self.largestCellCenter(polygon, inside: rooms[index].id, of: self) else { continue }
            rooms[index].labelX = center.x
            rooms[index].labelY = center.y
        }
    }

    /// 방 이름 자리를 방 넓이의 무게중심으로 옮긴다. 무게중심이 방 밖이면(ㄷ자 방 등) 방 안 가장 넓은 칸 가운데로
    mutating func centerRoomLabel(id: String) {
        guard let index = rooms.firstIndex(where: { $0.id == id }) else { return }
        let points = polygon(of: rooms[index])
        let area = Self.signedArea(points)
        guard abs(area) > WallMoveRules.eps else { return }
        var center = SIMD2<Double>(0, 0)
        for i in points.indices {
            let a = points[i]
            let b = points[(i + 1) % points.count]
            center += (a + b) * (a.x * b.y - b.x * a.y)
        }
        center /= 6 * area
        if room(containing: center)?.id == id {
            rooms[index].labelX = center.x
            rooms[index].labelY = center.y
        } else {
            // 가장 넓은 칸도 못 찾으면(세모 방 등) 무게중심에라도 둔다. 이름 자리가 비어 화면 밖에 그려지지 않게
            let spot = Self.largestCellCenter(points, inside: id, of: self) ?? center
            rooms[index].labelX = spot.x
            rooms[index].labelY = spot.y
        }
    }

    /// 화면 시계 방향이면 양수인 다각형 넓이
    static func signedArea(_ points: [SIMD2<Double>]) -> Double {
        var sum = 0.0
        for index in points.indices {
            let a = points[index]
            let b = points[(index + 1) % points.count]
            sum += a.x * b.y - b.x * a.y
        }
        return sum / 2
    }

    /// 양 끝이 모두 다른 벽과 이어진 벽들. 한쪽이 떠 있는 벽은 이어진 벽이 없어질 때까지 빼 나간다
    private func loopedWalls() -> Set<String> {
        var remaining = Set(walls.map(\.id))
        while true {
            var degree: [String: Int] = [:]
            for wall in walls where remaining.contains(wall.id) {
                degree[wall.startVertex, default: 0] += 1
                degree[wall.endVertex, default: 0] += 1
            }
            let dangling = walls.filter { remaining.contains($0.id) && (degree[$0.startVertex] == 1 || degree[$0.endVertex] == 1) }
            if dangling.isEmpty { return remaining }
            for wall in dangling { remaining.remove(wall.id) }
        }
    }

    private static func largestCellCenter(_ polygon: [SIMD2<Double>], inside roomId: String, of plan: PlanData) -> SIMD2<Double>? {
        let xs = Array(Set(polygon.map(\.x))).sorted()
        let ys = Array(Set(polygon.map(\.y))).sorted()
        var best: (point: SIMD2<Double>, area: Double)?
        for i in xs.indices.dropLast() {
            for j in ys.indices.dropLast() {
                let center = SIMD2((xs[i] + xs[i + 1]) / 2, (ys[j] + ys[j + 1]) / 2)
                let area = (xs[i + 1] - xs[i]) * (ys[j + 1] - ys[j])
                if plan.room(containing: center)?.id == roomId, best == nil || area > best!.area {
                    best = (center, area)
                }
            }
        }
        return best?.point
    }
}

// 이름 없는 칸에 공간 이름 달기
extension PlanData {
    /// 점 point를 품은, 아직 방(Room)이 없는 닫힌 칸의 경계. 이미 방 안이거나 벽으로 닫힌 칸이 아니면 nil.
    /// 칸이 겹쳐 있으면(칸 안의 칸) 가장 작은 칸
    func unlabeledCell(containing point: SIMD2<Double>) -> [RoomEdge]? {
        guard room(containing: point) == nil, let loops = faceLoops() else { return nil }
        let takenSides = Set(rooms.flatMap(\.boundary).map { "\($0.wallId)/\($0.forward)" })
        return loops
            .filter { loop in
                loop.area > WallMoveRules.eps
                    && !loop.edges.contains { takenSides.contains("\($0.wallId)/\($0.forward)") }
                    && Self.polygon(points(of: loop.edges), contains: point)
            }
            .min { $0.area < $1.area }?
            .edges
    }

    /// 이름 없는 칸에 공간 이름을 point 자리에 새로 단다. 달았으면 새 방의 id, 달 칸이 없으면 nil
    mutating func addRoom(at point: SIMD2<Double>) -> String? {
        guard let boundary = unlabeledCell(containing: point) else { return nil }
        let id = UUID().uuidString
        rooms.append(Room(id: id, name: RoomCopy.newRoomName, boundary: boundary, labelX: point.x, labelY: point.y))
        return id
    }
}

// 문구
private enum RoomCopy {
    /// 벽을 그려 새로 생긴 방의 이름. 공간라벨로 고칠 수 있다
    static let newRoomName = "새 공간"
}

// 벽 연결에서 방 경계(Room.boundary)를 다시 만들고, 방 밖으로 나간 이름 자리를 방 안으로 옮긴다
//
// 면 따라 돌기: 벽 하나를 방향이 반대인 두 "면"으로 본다. 면을 따라가다 꼭짓점에 닿으면 가장 오른쪽으로 꺾는다.
// 이렇게 돌면 방은 화면에서 시계 방향(넓이 +)으로, 건물 바깥은 반시계 방향(넓이 −)으로 한 바퀴 돈다.
// 방 이름 잇기: 옮기기 전에 어떤 면이 어느 방이었는지 기억해 두고, 다시 돈 고리에 그 면이 있으면 같은 방으로 본다.
// 벽 이동은 방을 새로 만들거나 없애지 않으므로 고리와 방은 하나씩 짝이 맞아야 한다. 안 맞으면 실패

import Foundation

extension PlanData {
    /// 방 경계를 다시 만든다. 고리와 방의 짝이 맞지 않으면 바꾸지 않고 false
    mutating func retraceRooms() -> Bool {
        let pos = vertexPoints
        // 한쪽 끝이 어디에도 이어지지 않은 벽(따로 세운 벽 등)은 방을 나누지 않으므로 빼고 돈다
        let looped = loopedWalls()
        struct Side { let wallId: String; let forward: Bool; let from: String; let to: String; let angle: Double }
        var sides: [Side] = []
        for wall in walls where looped.contains(wall.id) {
            guard let a = pos[wall.startVertex], let b = pos[wall.endVertex] else { return false }
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

        var roomOfSide: [String: String] = [:]
        for room in rooms { for edge in room.boundary { roomOfSide["\(edge.wallId)/\(edge.forward)"] = room.id } }

        var visited = Set<Int>()
        var boundaries: [String: [RoomEdge]] = [:]
        var outerCount = 0
        for start in sides.indices where !visited.contains(start) {
            var loop: [Int] = []
            var current = start
            repeat {
                visited.insert(current)
                loop.append(current)
                current = next(current)
            } while current != start
            let area = Self.signedArea(loop.map { pos[sides[$0].from]! })
            let names = Set(loop.compactMap { roomOfSide["\(sides[$0].wallId)/\(sides[$0].forward)"] })
            if area > WallMoveRules.eps {
                // 방이 아닌 닫힌 고리(이름이 없는 칸)는 그대로 둔다
                guard names.count <= 1 else { return false }
                guard let name = names.first else { continue }
                guard boundaries[name] == nil else { return false }
                boundaries[name] = loop.map { RoomEdge(wallId: sides[$0].wallId, forward: sides[$0].forward) }
            } else {
                guard names.isEmpty else { return false }
                outerCount += 1
            }
        }
        guard outerCount >= 1, boundaries.count == rooms.count else { return false }
        for index in rooms.indices {
            guard var boundary = boundaries[rooms[index].id] else { return false }
            // 시작 벽이 그대로 있으면 시작을 맞춰 둔다
            if let first = rooms[index].boundary.first, let at = boundary.firstIndex(of: first) {
                boundary = Array(boundary[at...] + boundary[..<at])
            }
            rooms[index].boundary = boundary
        }
        return true
    }

    /// 이름 자리가 방 밖으로 나간 방은, 방을 x·y 좌표로 격자처럼 잘라 방 안에서 가장 넓은 칸의 가운데로 옮긴다
    mutating func refreshRoomLabels() {
        for index in rooms.indices {
            let polygon = polygon(of: rooms[index])
            let label = SIMD2(rooms[index].labelX, rooms[index].labelY)
            guard room(containing: label)?.id != rooms[index].id,
                  let center = Self.largestCellCenter(polygon, inside: rooms[index].id, of: self) else { continue }
            rooms[index].labelX = center.x
            rooms[index].labelY = center.y
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

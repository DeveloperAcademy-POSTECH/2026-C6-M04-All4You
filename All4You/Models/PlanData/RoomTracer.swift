// 벽 연결에서 닫힌 칸(면 따라 돌기)을 찾는다
//
// 면 따라 돌기: 벽 하나를 방향이 반대인 두 "면"으로 본다. 면을 따라가다 꼭짓점에 닿으면 가장 오른쪽으로 꺾는다.
// 이렇게 돌면 닫힌 칸은 화면에서 시계 방향(넓이 +)으로, 건물 바깥은 반시계 방향(넓이 −)으로 한 바퀴 돈다.
// 벽을 고쳐도 칸과 공간 라벨의 짝을 맞추지 않는다. 라벨은 이름과 자리(점)만 갖고, 영역은 PlanRegions가 그때그때 계산한다

import Foundation

extension PlanData {
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

    /// 방 경계 벽들을 도는 방향 쪽 시작점으로 바꾼 점들
    func points(of boundary: [RoomEdge]) -> [SIMD2<Double>] {
        polygon(of: Room(id: "", name: "", boundary: boundary, labelX: 0, labelY: 0))
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
}

// 문구
enum RoomCopy {
    /// 벽을 그려 새로 생긴 방의 이름. 공간라벨로 고칠 수 있다
    static let newRoomName = "새 공간"
}

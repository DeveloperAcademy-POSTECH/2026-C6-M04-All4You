// 지우개가 남긴 가상 경계선 가운데 쓸모없어진 것을 정리한다
//
// 지우개로 바깥벽을 지우면 벽이 실제로 빠지지 않고 가상 경계선(isVirtual)으로 바뀐다. 방 경계(Room.boundary)가 그 벽을 가리키기 때문이다.
// 그대로 쌓이면 방을 다 지워도 안 보이는 선으로 닫힌 칸이 남아, 그 자리에 새 방을 그릴 때 공간 라벨이 겹쳐 달린다.
// 그래서 아래 세 규칙을 차례로 돈다.
// 1. 틈은 곧게 잇기: 이어진 가상 경계선 여러 개를, 남은 벽 끝끼리 잇는 곧은 선 하나로 바꾼다
// 2. 빈 방 지우기: 진짜 벽이 하나도 없거나 넓이가 없어진 방을 지운다
// 3. 주인 없는 선 지우기: 어느 방의 경계도 아닌 가상 경계선을 지운다

import Foundation

extension PlanData {
    /// 가상 경계선을 정리한다. 정리할 가상 경계선이 없으면 아무것도 하지 않는다.
    /// 방 경계를 다시 만들 수 없으면 도면을 바꾸지 않고 false
    @discardableResult
    mutating func cleanUpVirtualWalls() -> Bool {
        guard walls.contains(where: \.isVirtual) else { return true }
        var result = self
        result.straightenVirtualChains()
        result.removeRoomsWithoutWalls()
        result.removeUnownedVirtualWalls()
        // 방이 남아 있으면 고리와 방이 하나씩 짝이 맞는지 확인한다. 방이 없으면 맞출 것이 없다
        if !result.rooms.isEmpty {
            guard result.retraceRooms() else { return false }
            result.refreshRoomLabels()
        }
        self = result
        return true
    }

    // 규칙 1

    /// 이어진 가상 경계선 한 줄. vertices는 차례로 지나는 꼭짓점 id (길이 = walls 수 + 1), walls는 그 사이의 벽 id
    private struct VirtualChain {
        var vertices: [String]
        var walls: [String]
    }

    /// 가상 경계선만 이어진 줄들. 줄 가운데 꼭짓점에는 다른 벽이 붙어 있지 않다. 한 바퀴 도는 닫힌 줄은 끝이 없어 뺀다
    private func virtualChains() -> [VirtualChain] {
        var degree: [String: Int] = [:]
        var virtualWalls: [String: [Wall]] = [:]
        for wall in walls {
            degree[wall.startVertex, default: 0] += 1
            degree[wall.endVertex, default: 0] += 1
            if wall.isVirtual {
                virtualWalls[wall.startVertex, default: []].append(wall)
                virtualWalls[wall.endVertex, default: []].append(wall)
            }
        }
        func isInterior(_ vertexId: String) -> Bool {
            degree[vertexId] == 2 && virtualWalls[vertexId]?.count == 2
        }
        /// 꼭짓점 vertexId에서 wall이 아닌 다른 가상 경계선과 그 건너편 꼭짓점
        func onward(from vertexId: String, past wall: Wall) -> (wall: Wall, vertex: String)? {
            guard isInterior(vertexId), let other = virtualWalls[vertexId]?.first(where: { $0.id != wall.id }) else { return nil }
            return (other, other.startVertex == vertexId ? other.endVertex : other.startVertex)
        }

        var visited = Set<String>()
        var chains: [VirtualChain] = []
        for wall in walls where wall.isVirtual && !visited.contains(wall.id) {
            visited.insert(wall.id)
            var chain = VirtualChain(vertices: [wall.startVertex, wall.endVertex], walls: [wall.id])
            var isClosed = false
            var tail = wall
            while let step = onward(from: chain.vertices[chain.vertices.count - 1], past: tail) {
                if visited.contains(step.wall.id) { isClosed = true; break }
                visited.insert(step.wall.id)
                chain.walls.append(step.wall.id)
                chain.vertices.append(step.vertex)
                tail = step.wall
            }
            var head = wall
            while !isClosed, let step = onward(from: chain.vertices[0], past: head) {
                if visited.contains(step.wall.id) { isClosed = true; break }
                visited.insert(step.wall.id)
                chain.walls.insert(step.wall.id, at: 0)
                chain.vertices.insert(step.vertex, at: 0)
                head = step.wall
            }
            if !isClosed { chains.append(chain) }
        }
        return chains
    }

    /// 둘 이상 이어진 가상 경계선을 양 끝을 잇는 곧은 선 하나로 바꾼다. 곧은 선이 진짜 벽을 가로지르거나 이미 그 자리에 벽이 있으면 바꾸지 않는다
    private mutating func straightenVirtualChains() {
        for chain in virtualChains() where chain.walls.count >= 2 {
            replace(chain)
        }
    }

    private mutating func replace(_ chain: VirtualChain) {
        let startId = chain.vertices[0]
        let endId = chain.vertices[chain.vertices.count - 1]
        let pos = vertexPoints
        guard startId != endId, let a = pos[startId], let b = pos[endId], !hasWall(between: startId, and: endId),
              let first = wall(id: chain.walls[0]) else { return }
        let chainWalls = Set(chain.walls)
        guard !doorWindows.contains(where: { chainWalls.contains($0.wallId) }),
              !wallFixtures.contains(where: { chainWalls.contains($0.wallId) }) else { return }

        let straight = Wall(id: UUID().uuidString, startVertex: startId, endVertex: endId,
                            thickness: first.thickness, height: first.height, isVirtual: true)
        let straightLine = WallLine(start: a, end: b)
        let eps = WallMoveRules.eps
        for other in walls where !chainWalls.contains(other.id) {
            guard let otherLine = line(of: other) else { continue }
            if [other.startVertex, other.endVertex].contains(startId) || [other.startVertex, other.endVertex].contains(endId) {
                // 끝을 함께 쓰는 벽이 곧은 선을 따라 겹치면 안 된다
                let free = [other.startVertex, other.endVertex].filter { $0 != startId && $0 != endId }
                if free.contains(where: { id in pos[id].map { straightLine.distance(to: $0) < eps } ?? false }) { return }
            } else if Self.segmentsTouch(straightLine, otherLine) {
                return
            }
        }

        // 방 경계에서 이 줄을 지나던 자리는 곧은 선 하나로 바꾼다. 지나는 방향은 줄 방향과 같은지로 잰다
        for r in rooms.indices {
            var boundary: [RoomEdge] = []
            var lastWasStraight = false
            for edge in rooms[r].boundary {
                guard let index = chain.walls.firstIndex(of: edge.wallId), let wall = wall(id: edge.wallId) else {
                    boundary.append(edge)
                    lastWasStraight = false
                    continue
                }
                let from = edge.forward ? wall.startVertex : wall.endVertex
                let alongChain = from == chain.vertices[index]
                let replacement = RoomEdge(wallId: straight.id, forward: alongChain)
                if !(lastWasStraight && boundary.last == replacement) { boundary.append(replacement) }
                lastWasStraight = true
            }
            // 경계의 끝과 처음에 걸쳐 있던 줄은 한 번만 센다
            if boundary.count > 1, boundary.first?.wallId == straight.id, boundary.first == boundary.last { boundary.removeLast() }
            rooms[r].boundary = boundary
        }
        walls.removeAll { chainWalls.contains($0.id) }
        walls.append(straight)
        removeUnusedVertices()
    }

    // 규칙 2

    /// 진짜 벽이 하나도 없거나 넓이가 없어진 방을 지운다. 그 방의 가상 경계선은 규칙 3이 치운다.
    /// 그 방에 놓였던 사진·메모는 장소가 없어진다(라벨을 지울 때와 같다)
    private mutating func removeRoomsWithoutWalls() {
        let realWalls = Set(walls.filter { !$0.isVirtual }.map(\.id))
        let empty = Set(rooms.filter { room in
            !room.boundary.contains { realWalls.contains($0.wallId) }
                || abs(Self.signedArea(polygon(of: room))) <= WallMoveRules.eps
        }.map(\.id))
        rooms.removeAll { empty.contains($0.id) }
    }

    // 규칙 3

    /// 어느 방의 경계도 아닌 가상 경계선과, 그 벽만 쓰던 꼭짓점을 지운다
    private mutating func removeUnownedVirtualWalls() {
        let owned = Set(rooms.flatMap(\.boundary).map(\.wallId))
        walls.removeAll { $0.isVirtual && !owned.contains($0.id) }
        removeUnusedVertices()
    }

    private mutating func removeUnusedVertices() {
        let used = Set(walls.flatMap { [$0.startVertex, $0.endVertex] })
        vertices.removeAll { !used.contains($0.id) }
    }
}

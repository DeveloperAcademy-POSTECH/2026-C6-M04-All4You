// 공간 스캔 도면의 방 자동 나누기. 스캔은 방 경계를 주지 않고 방 종류와 가운데 점만 주므로, 벽에서 방을 찾는다
//
// 1) T자 나누기: 떠 있는 벽 끝이 다른 벽 중간 가까이 있으면 그 벽 위에 꼭짓점을 만들고 그 벽을 둘로 나눈다
//    (스캔의 바깥 벽은 통으로 한 면이라 이 단계가 없으면 칸막이가 방을 닫지 못한다)
// 2) 틈 메우기: 그래도 떠 있는 끝은 짧은 틈이면 벽을 늘려 가장 가까운 벽에 잇는다
// 3) 방 찾기: 면 따라 돌기로 닫힌 고리를 찾고, 바깥 고리와 아주 작은 칸은 버린다
// 4) 이름: 방 안에 든 종류를 이어 붙이고("거실·주방"), 없으면 "공간 N", 같은 이름이 여럿이면 번호를 붙인다
// 벽 없이 이어진 공간(거실–주방 등)은 하나의 방으로 둔다

import Foundation
import simd

extension PlanData {
    /// 떠 있는 벽 끝을 잇고 방을 만든다. sections: 도면 좌표의 방 종류와 가운데 점
    mutating func addScanRooms(sections: [(name: String?, point: SIMD2<Double>)]) {
        for vertexId in danglingVertexIds() {
            connectDanglingEnd(vertexId)
        }
        // TODO: 긴 틈이 바깥쪽에 있으면 바닥 윤곽선으로 가상 경계선(isVirtual)을 넣어 방을 닫기 — 지금은 그 방이 만들어지지 않음
        makeRooms(sections: sections)
    }
}

// 떠 있는 벽 끝 잇기
extension PlanData {
    /// 벽 하나에만 붙은 꼭짓점들
    private func danglingVertexIds() -> [String] {
        var degree: [String: Int] = [:]
        for wall in walls {
            degree[wall.startVertex, default: 0] += 1
            degree[wall.endVertex, default: 0] += 1
        }
        return vertices.map(\.id).filter { degree[$0] == 1 }
    }

    /// 떠 있는 끝 하나를 가까운 벽(T자) → 늘려서 닿는 벽 → 가까운 다른 떠 있는 끝 순서로 잇는다
    private mutating func connectDanglingEnd(_ vertexId: String) {
        guard danglingVertexIds().contains(vertexId),
              let own = walls.first(where: { $0.startVertex == vertexId || $0.endVertex == vertexId }),
              let ownLine = line(of: own),
              let point = vertexPoints[vertexId] else { return }
        let others = walls.filter { $0.id != own.id }

        // T자: 다른 벽까지 거리가 가까우면 그 벽 위로
        if let nearest = others.min(by: { distance(point, $0) < distance(point, $1) }),
           distance(point, nearest) <= ScanRoomRule.tJoinDistance {
            attach(vertexId, to: nearest.id, near: point)
            return
        }
        // 틈 메우기: 벽 방향으로 늘려 짧은 거리 안에 닿는 벽
        let outward = own.startVertex == vertexId ? -ownLine.direction : ownLine.direction
        if let hit = others.compactMap({ wall in rayHit(from: point, toward: outward, wall: wall).map { (wall, $0) } })
            .filter({ $0.1 <= ScanRoomRule.gapFillDistance })
            .min(by: { $0.1 < $1.1 }) {
            attach(vertexId, to: hit.0.id, near: point + outward * hit.1)
            return
        }
        // 가까운 다른 떠 있는 끝과 합치기
        let otherEnd = own.startVertex == vertexId ? own.endVertex : own.startVertex
        if let partner = danglingVertexIds()
            .filter({ $0 != vertexId && $0 != otherEnd })
            .compactMap({ id in vertexPoints[id].map { (id, simd_distance($0, point)) } })
            .filter({ $0.1 <= ScanRoomRule.gapFillDistance })
            .min(by: { $0.1 < $1.1 }) {
            merge(vertexId, into: partner.0)
        }
    }

    /// 꼭짓점을 벽 위의 점으로 옮겨 붙인다. 벽 끝 가까이면 그 끝 꼭짓점과 합치고, 중간이면 벽을 둘로 나눈다
    private mutating func attach(_ vertexId: String, to wallId: String, near point: SIMD2<Double>) {
        guard let wall = wall(id: wallId), let line = line(of: wall) else { return }
        let along = min(max(simd_dot(point - line.start, line.direction), 0), line.length)
        if along <= ScanRoomRule.endSnapDistance {
            merge(vertexId, into: wall.startVertex)
        } else if along >= line.length - ScanRoomRule.endSnapDistance {
            merge(vertexId, into: wall.endVertex)
        } else {
            let onWall = line.point(along: along)
            if let index = vertices.firstIndex(where: { $0.id == vertexId }) {
                vertices[index].x = onWall.x
                vertices[index].y = onWall.y
            }
            split(wallId, at: vertexId, along: along)
        }
    }

    /// 벽을 꼭짓점에서 둘로 나눈다. 앞쪽은 원래 id, 뒤쪽은 새 id. 문·창문은 가운데가 있는 쪽으로 옮긴다
    private mutating func split(_ wallId: String, at vertexId: String, along: Double) {
        guard let index = walls.firstIndex(where: { $0.id == wallId }) else { return }
        let original = walls[index]
        let fullLength = line(of: original)?.length ?? along
        let backId = Self.newId("w", among: walls.map(\.id))
        walls[index].endVertex = vertexId
        walls.append(Wall(id: backId, startVertex: vertexId, endVertex: original.endVertex,
                          thickness: original.thickness, height: original.height, isVirtual: original.isVirtual))
        for i in doorWindows.indices where doorWindows[i].wallId == wallId {
            var item = doorWindows[i]
            let pieceLength: Double
            if item.centerAlongWall > along {
                item.wallId = backId
                item.centerAlongWall -= along
                pieceLength = fullLength - along
            } else {
                pieceLength = along
            }
            // 나눈 자리에 걸친 문·창문은 그 조각 안으로 줄이고 옮긴다
            item.width = min(item.width, pieceLength)
            item.centerAlongWall = min(max(item.centerAlongWall, item.width / 2), pieceLength - item.width / 2)
            doorWindows[i] = item
        }
    }

    /// 꼭짓점 하나를 다른 꼭짓점으로 합친다. 두 끝이 같아진 벽과 겹치는 벽은 지운다
    private mutating func merge(_ vertexId: String, into targetId: String) {
        guard vertexId != targetId else { return }
        for i in walls.indices {
            if walls[i].startVertex == vertexId { walls[i].startVertex = targetId }
            if walls[i].endVertex == vertexId { walls[i].endVertex = targetId }
        }
        var seen = Set<[String]>()
        let removed = walls.filter { wall in
            wall.startVertex == wall.endVertex
                || !seen.insert([wall.startVertex, wall.endVertex].sorted()).inserted
        }.map(\.id)
        walls.removeAll { removed.contains($0.id) }
        doorWindows.removeAll { removed.contains($0.wallId) }
        vertices.removeAll { $0.id == vertexId }
    }

    private func distance(_ point: SIMD2<Double>, _ wall: Wall) -> Double {
        line(of: wall)?.distance(to: point) ?? .infinity
    }

    /// 점에서 쏜 반직선이 벽 선분에 닿는 거리. 닿지 않으면 nil
    private func rayHit(from point: SIMD2<Double>, toward direction: SIMD2<Double>, wall: Wall) -> Double? {
        guard let line = line(of: wall) else { return nil }
        let edge = line.end - line.start
        let cross = direction.x * edge.y - direction.y * edge.x
        guard abs(cross) > 1e-9 else { return nil }
        let diff = line.start - point
        let along = (diff.x * edge.y - diff.y * edge.x) / cross
        let ratio = (diff.x * direction.y - diff.y * direction.x) / cross
        return along > 0 && ratio >= 0 && ratio <= 1 ? along : nil
    }

    /// prefix 뒤에 숫자를 붙여 아직 없는 id를 만든다
    private static func newId(_ prefix: String, among ids: [String]) -> String {
        var number = ids.count + 1
        while ids.contains("\(prefix)\(number)") { number += 1 }
        return "\(prefix)\(number)"
    }
}

// 방 만들기
extension PlanData {
    private mutating func makeRooms(sections: [(name: String?, point: SIMD2<Double>)]) {
        guard let loops = faceLoops() else { return }
        struct Found { let boundary: [RoomEdge]; let name: String?; let label: SIMD2<Double>?; let center: SIMD2<Double> }
        var found: [Found] = []
        for loop in loops where loop.area >= ScanRoomRule.minRoomArea {
            let polygon = polygon(of: Room(id: "", name: "", boundary: loop.edges, labelX: 0, labelY: 0))
            let inside = sections.filter { Self.polygon(polygon, contains: $0.point) }
            // 여러 종류가 든 방(벽 없이 이어진 거실·주방)은 이름을 이어 붙인다
            var names: [String] = []
            for name in inside.compactMap(\.name) where !names.contains(name) { names.append(name) }
            found.append(Found(
                boundary: loop.edges,
                name: names.isEmpty ? nil : names.joined(separator: "·"),
                label: inside.first?.point,
                center: polygon.reduce(.zero, +) / Double(polygon.count)
            ))
        }
        // 번호가 읽는 순서(위 → 아래, 왼쪽 → 오른쪽)로 붙도록 방을 줄 세운다. 1m 안의 높이 차이는 같은 줄로 본다
        found.sort { ($0.center.y.rounded(), $0.center.x) < ($1.center.y.rounded(), $1.center.x) }

        // 이름 없는 방은 "공간 1", "공간 2" …, 같은 이름이 여럿이면 "침실 1", "침실 2" …
        let totals = Dictionary(found.compactMap(\.name).map { ($0, 1) }, uniquingKeysWith: +)
        var seenCount: [String: Int] = [:]
        var unnamedCount = 0
        rooms = found.enumerated().map { index, room in
            let name: String
            if let base = room.name {
                seenCount[base, default: 0] += 1
                name = totals[base, default: 0] > 1 ? "\(base) \(seenCount[base]!)" : base
            } else {
                unnamedCount += 1
                name = "\(ScanRoomRule.unnamedRoom) \(unnamedCount)"
            }
            // 이름 자리가 없으면 아래 centerRoomLabel이 방 안으로 놓는다
            return Room(id: "r\(index + 1)", name: name, boundary: room.boundary,
                        labelX: room.label?.x ?? .infinity, labelY: room.label?.y ?? .infinity)
        }
        for room in rooms where !room.labelX.isFinite {
            centerRoomLabel(id: room.id)
        }
    }
}

/// 방 나누기에 쓰는 값 (m, ㎡)
private enum ScanRoomRule {
    /// 떠 있는 끝이 이 거리 안의 벽에 닿으면 그 벽 위로 붙인다 (T자)
    static let tJoinDistance = 0.1
    /// 이보다 짧은 틈은 벽을 늘려 잇는다
    static let gapFillDistance = 0.3
    /// 벽 끝에서 이 거리 안이면 벽을 나누지 않고 끝 꼭짓점과 합친다
    static let endSnapDistance = 0.1
    /// 이보다 작은 칸은 방으로 보지 않는다
    static let minRoomArea = 0.5
    /// 이름 없는 방에 붙이는 이름. 뒤에 1부터 번호를 붙인다
    static let unnamedRoom = "공간"
}

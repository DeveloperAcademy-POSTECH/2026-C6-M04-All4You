// 공간 스캔 도면의 공간 라벨 자동 만들기. 스캔은 방 경계를 주지 않고 방 종류와 가운데 점만 주므로, 영역(PlanRegions)에서 라벨을 놓을 곳을 찾는다
//
// 1) T자 나누기: 떠 있는 벽 끝이 다른 벽 중간 가까이 있으면 그 벽 위에 꼭짓점을 만들고 그 벽을 둘로 나눈다
//    (스캔의 바깥 벽은 통으로 한 면이라 이 단계가 없으면 칸막이가 방을 닫지 못한다)
// 2) 틈 메우기: 그래도 떠 있는 끝은 짧은 틈이면 벽을 늘려 가장 가까운 벽에 잇는다. 긴 틈은 잇지 않는다 (스캔하지 않은 선을 만들어 넣지 않음)
// 3) 라벨: 스캔이 알아본 방 종류마다 그 자리에 라벨 하나(같은 영역에 든 종류는 "거실·주방"처럼 이름을 이어 붙임).
//    라벨이 없는 영역(벽으로 닫힌 칸, 그다음 바닥)에는 가운데에 "공간 N". 같은 이름이 여럿이면 번호를 붙인다
// 벽 없이 이어진 공간(거실–주방 등)은 하나의 영역으로 둔다

import Foundation
import simd

extension PlanData {
    /// 떠 있는 벽 끝을 잇고 공간 라벨을 만든다. sections: 도면 좌표의 방 종류와 가운데 점
    mutating func addScanRooms(sections: [(name: String?, point: SIMD2<Double>)]) {
        for vertexId in danglingVertexIds() {
            connectDanglingEnd(vertexId)
        }
        makeRoomLabels(sections: sections)
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

    /// 꼭짓점 하나를 다른 꼭짓점으로 합친다. 두 끝이 같아진 벽은 지운다.
    /// 이미 같은 두 꼭짓점을 잇는 벽이 있어 겹치게 된 벽도 지우되, 그 벽의 문·창문은 남은 벽으로 옮긴다
    private mutating func merge(_ vertexId: String, into targetId: String) {
        guard vertexId != targetId else { return }
        for i in walls.indices {
            if walls[i].startVertex == vertexId { walls[i].startVertex = targetId }
            if walls[i].endVertex == vertexId { walls[i].endVertex = targetId }
        }
        var keptOfPair: [[String]: Wall] = [:]
        var removed: [String] = []
        var overlapped: [String: (removed: Wall, kept: Wall)] = [:]
        for wall in walls {
            guard wall.startVertex != wall.endVertex else {
                removed.append(wall.id)
                continue
            }
            let key = [wall.startVertex, wall.endVertex].sorted()
            if let kept = keptOfPair[key] {
                removed.append(wall.id)
                overlapped[wall.id] = (wall, kept)
            } else {
                keptOfPair[key] = wall
            }
        }
        walls.removeAll { removed.contains($0.id) }
        vertices.removeAll { $0.id == vertexId }
        for i in doorWindows.indices {
            if let pair = overlapped[doorWindows[i].wallId] {
                doorWindows[i] = movedItem(doorWindows[i], from: pair.removed, to: pair.kept)
            }
        }
        // 두 끝이 같아져 사라진 벽(옮길 곳이 없음)의 문·창문만 지운다
        doorWindows.removeAll { removed.contains($0.wallId) }
    }

    /// 겹친 벽(같은 두 끝)의 문·창문을 남은 벽으로 옮긴다. 두 벽의 방향이 반대면 위치를 뒤집고, 벽 길이 안으로 줄인다
    private func movedItem(_ item: DoorWindow, from old: Wall, to kept: Wall) -> DoorWindow {
        var moved = item
        moved.wallId = kept.id
        guard let length = line(of: kept)?.length else { return moved }
        if old.startVertex != kept.startVertex {
            moved.centerAlongWall = length - moved.centerAlongWall
        }
        moved.width = min(moved.width, length)
        moved.centerAlongWall = min(max(moved.centerAlongWall, moved.width / 2), length - moved.width / 2)
        return moved
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

// 공간 라벨 만들기
extension PlanData {
    private mutating func makeRoomLabels(sections: [(name: String?, point: SIMD2<Double>)]) {
        let regions = self.regions
        struct Found { var name: String?; var point: SIMD2<Double> }

        // 스캔이 알아본 방 종류: 같은 영역에 든 것은 이름을 이어 붙여 하나 (벽 없이 이어진 거실·주방). 어느 영역에도 없으면 그 자리에 따로
        var groups: [(region: PlanRegions.Region?, names: [String], point: SIMD2<Double>)] = []
        for section in sections {
            let region = regions.region(containing: section.point)
            if let region, let at = groups.firstIndex(where: { $0.region == region }) {
                if let name = section.name, !groups[at].names.contains(name) { groups[at].names.append(name) }
            } else {
                groups.append((region, section.name.map { [$0] } ?? [], section.point))
            }
        }
        var found = groups.map { Found(name: $0.names.isEmpty ? nil : $0.names.joined(separator: "·"), point: $0.point) }

        // 라벨이 없는 영역에는 가운데에 이름 없는 라벨을 놓는다. 닫힌 칸이 먼저이고, 그다음 바닥이다.
        // 이미 라벨이 있는 영역 안에 든 바닥은 건너뛴다 (닫힌 칸 안에 완전히 든 바닥 등)
        for region in regions.regions where region.area >= ScanRoomRule.minRoomArea {
            let point = Self.interiorPoint(of: region.polygon)
            if region.isClosedCell {
                guard !found.contains(where: { regions.region(containing: $0.point) == region }) else { continue }
            } else {
                guard !found.contains(where: { Self.polygon(region.polygon, contains: $0.point) }),
                      let holder = regions.region(containing: point),
                      !found.contains(where: { regions.region(containing: $0.point) == holder }) else { continue }
            }
            found.append(Found(name: nil, point: point))
        }
        // 번호가 읽는 순서(위 → 아래, 왼쪽 → 오른쪽)로 붙도록 줄 세운다. 1m 안의 높이 차이는 같은 줄로 본다
        found.sort { ($0.point.y.rounded(), $0.point.x) < ($1.point.y.rounded(), $1.point.x) }

        // 이름 없는 라벨은 "공간 1", "공간 2" …, 같은 이름이 여럿이면 "침실 1", "침실 2" …
        let totals = Dictionary(found.compactMap(\.name).map { ($0, 1) }, uniquingKeysWith: +)
        var seenCount: [String: Int] = [:]
        var unnamedCount = 0
        rooms = found.enumerated().map { index, label in
            let name: String
            if let base = label.name {
                seenCount[base, default: 0] += 1
                name = totals[base, default: 0] > 1 ? "\(base) \(seenCount[base]!)" : base
            } else {
                unnamedCount += 1
                name = "\(ScanRoomRule.unnamedRoom) \(unnamedCount)"
            }
            return Room(id: "r\(index + 1)", name: name, boundary: [], labelX: label.point.x, labelY: label.point.y)
        }
    }

    /// 다각형 안의 한 점. 넓이 무게중심이 안에 있으면 그 점, 아니면(ㄷ자 등) 무게중심 높이의 가로선이 다각형 안을 지나는 구간 가운데 가장 긴 구간의 가운데
    static func interiorPoint(of polygon: [SIMD2<Double>]) -> SIMD2<Double> {
        let area = signedArea(polygon)
        var centroid = polygon.reduce(.zero, +) / Double(max(polygon.count, 1))
        if abs(area) > WallMoveRules.eps {
            var sum = SIMD2<Double>.zero
            for index in polygon.indices {
                let a = polygon[index]
                let b = polygon[(index + 1) % polygon.count]
                sum += (a + b) * (a.x * b.y - b.x * a.y)
            }
            centroid = sum / (6 * area)
        }
        if self.polygon(polygon, contains: centroid) { return centroid }
        var crossings: [Double] = []
        for index in polygon.indices {
            let a = polygon[index]
            let b = polygon[(index + 1) % polygon.count]
            if (a.y > centroid.y) != (b.y > centroid.y) {
                crossings.append(a.x + (centroid.y - a.y) / (b.y - a.y) * (b.x - a.x))
            }
        }
        crossings.sort()
        let widest = stride(from: 0, to: crossings.count - 1, by: 2)
            .max { crossings[$0 + 1] - crossings[$0] < crossings[$1 + 1] - crossings[$1] }
        guard let widest else { return centroid }
        return SIMD2((crossings[widest] + crossings[widest + 1]) / 2, centroid.y)
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
    /// 이보다 작은 칸·바닥에는 이름 없는 라벨을 놓지 않는다
    static let minRoomArea = 0.5
    /// 이름 없는 방에 붙이는 이름. 뒤에 1부터 번호를 붙인다
    static let unnamedRoom = "공간"
}

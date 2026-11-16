// 벽 편집이 사용자의 동작을 거절하지 않고 스스로 처리하는 규칙 모음.
// 펜으로 벽 그리기, 꼭짓점 손잡이 끌기, 가로·세로 벽 옮기기, 비스듬한 벽 옮기기가 모두 이 규칙을 쓴다.
//
// 용어
// - 꼭짓점: 벽의 양 끝점 (Vertex). 벽은 꼭짓점 두 개를 이은 선이다
// - 달린 것: 벽에 달린 창문·문·개구부(DoorWindow)와 콘센트(WallFixture)
//
// 벽을 고치면 도면이 어긋날 수 있다. 막지 않고 아래를 자동으로 해서 도면이 맞게 한다.
// 1) 달린 것 맞추기(fitOpenings): 벽 길이가 바뀌면 그 벽의 창문·문을 원래 자리 → 벽 안으로 밀기 → 폭 줄이기 → 지우기 순으로 맞춘다
// 2) 가로지르면 나누기(splitCrossings): 벽이 다른 벽을 가로지르거나 닿으면 만나는 자리에 꼭짓점을 만들어 양쪽 벽을 나눈다
// 3) 겹친 벽 합치기(mergeOverlappingWalls): 같은 두 꼭짓점을 잇는 벽이 둘이면 하나만 남기고, 달린 것은 남는 벽으로 옮긴다
// 자동으로 지운 것은 WallEditOutcome.removed에 담아 두고, 손을 뗀 뒤 "창문 1개가 지워졌어요"처럼 안내한다

import Foundation

/// 벽 편집이 자동으로 지운 것의 종류
enum RemovedItem: Hashable {
    case door
    case window
    case passage
    case outlet
}

/// 벽 편집의 결과. 편집은 거절하지 않으므로 바뀐 도면과, 자동으로 지운 것을 함께 돌려준다
struct WallEditOutcome {
    /// 편집을 반영한 도면. 편집할 것이 없었으면 원래 도면 그대로다
    var plan: PlanData
    /// 편집하면서 자동으로 지운 창문·문·콘센트
    var removed: [RemovedItem] = []

    /// 지워진 것이 있으면 손을 뗀 뒤 띄울 안내 글자
    // TEMP: 안내 문구는 디자인 확정 전이라 임시로 정함
    var removedNotice: String? {
        let names: [(RemovedItem, String)] = [(.door, "문"), (.window, "창문"), (.passage, "개구부"), (.outlet, "콘센트")]
        let parts = names.compactMap { item, name -> String? in
            let count = removed.filter { $0 == item }.count
            return count > 0 ? "\(name) \(count)개" : nil
        }
        guard !parts.isEmpty else { return nil }
        return "\(parts.joined(separator: ", "))가 지워졌어요. 되돌리기로 복구할 수 있어요"
    }
}

extension DoorWindowKind {
    fileprivate var removedItem: RemovedItem {
        switch self {
        case .door: .door
        case .window: .window
        case .passage: .passage
        }
    }
}

// 1) 달린 것 맞추기
extension PlanData {
    /// 벽에 달린 창문·문·콘센트가 도면 위 어디에 있는지 (id → 도면 좌표). 벽을 고치기 전에 잡아 두고, 고친 뒤 fitOpenings에 넘긴다.
    /// 벽 길이가 바뀌어도 달린 것이 원래 있던 자리에 남게 하려는 것이다
    func attachedPlaces(onWalls wallIds: Set<String>) -> [String: SIMD2<Double>] {
        var places: [String: SIMD2<Double>] = [:]
        for opening in doorWindows where wallIds.contains(opening.wallId) {
            guard let wall = wall(id: opening.wallId), let line = line(of: wall) else { continue }
            places[opening.id] = line.point(along: opening.centerAlongWall)
        }
        for fixture in wallFixtures where wallIds.contains(fixture.wallId) {
            guard let wall = wall(id: fixture.wallId), let line = line(of: wall) else { continue }
            places[fixture.id] = line.point(along: fixture.positionAlongWall)
        }
        return places
    }

    /// 벽 길이·방향이 바뀐 뒤 그 벽의 창문·문·콘센트를 맞춘다. 순서는 다음과 같다.
    /// ① 원래 있던 도면 위 자리(placesBefore)에 그대로 둔다
    /// ② 벽 끝에 걸리면 벽 안쪽으로 민다 (벽 끝·서로 사이에 openingMargin 여백을 둔다)
    /// ③ 그래도 안 들어가면 폭을 같은 비율로 줄인다 (가장 좁은 폭은 minimumWindowSize)
    /// ④ 줄여도 안 되면 가장 좁은 것부터 지우고 removed에 적는다
    /// 콘센트는 폭이 없어 ②만 한다 (벽 길이가 0이 아니면 항상 들어간다). placesBefore에 없는 것은 지금 자리를 쓴다
    mutating func fitOpenings(onWalls wallIds: Set<String>, placesBefore: [String: SIMD2<Double>], removed: inout [RemovedItem]) {
        let eps = WallMoveRules.eps
        let margin = WallMoveRules.openingMargin
        for wallId in wallIds {
            guard let wall = wall(id: wallId) else { continue }
            guard let line = line(of: wall), line.length > eps else {
                removeAttached(toWall: wallId, removed: &removed)
                continue
            }
            func along(_ id: String, fallback: Double) -> Double {
                placesBefore[id].map { (($0 - line.start) * line.direction).sum() } ?? fallback
            }

            var items = doorWindows.indices
                .filter { doorWindows[$0].wallId == wallId }
                .map { (index: $0, along: along(doorWindows[$0].id, fallback: doorWindows[$0].centerAlongWall)) }
                .sorted { $0.along < $1.along }
            var widths = items.map { doorWindows[$0.index].width }
            var goneIds: [String] = []
            // 벽 길이 ≥ 모든 폭의 합 + 여백들(양 끝과 사이사이)이어야 다 들어간다. 모자라면 폭을 같은 비율로 줄이고,
            // 줄여도 가장 좁은 폭(minimumWindowSize)보다 좁아지면 가장 좁은 것 하나를 지우고 다시 따져 본다
            while !items.isEmpty {
                let slots = Double(items.count + 1)
                if widths.reduce(0, +) + margin * slots <= line.length + eps { break }
                let scale = (line.length - margin * slots) / widths.reduce(0, +)
                if scale > 0, widths.allSatisfy({ $0 * scale >= Self.minimumWindowSize - eps }) {
                    widths = widths.map { $0 * scale }
                    break
                }
                let narrowest = widths.indices.min { widths[$0] < widths[$1] }!
                goneIds.append(doorWindows[items[narrowest].index].id)
                items.remove(at: narrowest)
                widths.remove(at: narrowest)
            }
            // starts[k]는 k번째 창문·문의 시작 위치 (벽 시작점에서 잰 거리). 원래 자리에서 시작해 두 번 훑어 서로·벽 끝에서 여백만큼 떨어지게 민다
            var starts = items.indices.map { items[$0].along - widths[$0] / 2 }
            // 앞에서 뒤로: 앞 벽 끝이나 앞 창문과 겹치면 뒤로 민다
            var earliestStart = margin
            for k in starts.indices {
                starts[k] = max(starts[k], earliestStart)
                earliestStart = starts[k] + widths[k] + margin
            }
            // 뒤에서 앞으로: 뒤 벽 끝을 넘으면 앞으로 민다
            var latestEnd = line.length - margin
            for k in starts.indices.reversed() {
                starts[k] = min(starts[k], latestEnd - widths[k])
                latestEnd = starts[k] - margin
            }
            for k in items.indices {
                doorWindows[items[k].index].width = widths[k]
                doorWindows[items[k].index].centerAlongWall = starts[k] + widths[k] / 2
            }
            for id in goneIds {
                if let kind = doorWindows.first(where: { $0.id == id })?.kind { removed.append(kind.removedItem) }
                doorWindows.removeAll { $0.id == id }
            }
            for index in wallFixtures.indices where wallFixtures[index].wallId == wallId {
                let position = along(wallFixtures[index].id, fallback: wallFixtures[index].positionAlongWall)
                wallFixtures[index].positionAlongWall = min(max(position, 0), line.length)
            }
        }
    }

    /// 벽에 달린 창문·문·콘센트를 모두 지우고 removed에 적는다
    mutating func removeAttached(toWall wallId: String, removed: inout [RemovedItem]) {
        removed += doorWindows.filter { $0.wallId == wallId }.map { $0.kind.removedItem }
        removed += wallFixtures.filter { $0.wallId == wallId }.map { _ in RemovedItem.outlet }
        doorWindows.removeAll { $0.wallId == wallId }
        wallFixtures.removeAll { $0.wallId == wallId }
    }
}

// 2) 가로지르면 나누기
extension PlanData {
    /// 벽을 at(벽 시작점에서 거리, m)에서 나눌 때 그 자리에 걸린 문을 나눈 자리 옆으로 민다. 더 가까운 쪽부터 보고, 어느 쪽에도 안 들어가면 지우고 removed에 적는다.
    /// (창문은 나눈 자리에서 두 조각으로 나뉘지만, 문은 둘로 나눌 수 없어서 밀어낸다)
    mutating func pushDoors(offSplitAt at: Double, onWall wallId: String, length: Double, removed: inout [RemovedItem]) {
        let eps = WallMoveRules.eps
        let margin = WallMoveRules.openingMargin
        var goneIds: [String] = []
        for index in doorWindows.indices where doorWindows[index].wallId == wallId && doorWindows[index].kind == .door {
            let door = doorWindows[index]
            guard abs(door.centerAlongWall - at) < door.width / 2 else { continue }
            let frontCenter = at - margin - door.width / 2
            let backCenter = at + margin + door.width / 2
            let fitsFront = frontCenter - door.width / 2 >= margin - eps
            let fitsBack = backCenter + door.width / 2 <= length - margin + eps
            let prefersFront = abs(frontCenter - door.centerAlongWall) <= abs(backCenter - door.centerAlongWall)
            if fitsFront, prefersFront || !fitsBack {
                doorWindows[index].centerAlongWall = frontCenter
            } else if fitsBack {
                doorWindows[index].centerAlongWall = backCenter
            } else {
                goneIds.append(door.id)
            }
        }
        removed += goneIds.map { _ in RemovedItem.door }
        doorWindows.removeAll { goneIds.contains($0.id) }
    }

    /// wallIds의 벽이 다른 벽을 가로지르거나 다른 벽의 끝에 닿는 자리마다 꼭짓점을 두고 양쪽 벽을 나눈다.
    /// 나누면서 생긴 새 벽도 이어서 살핀다. 문이 걸린 자리는 splitWall이 문을 옆으로 민다
    mutating func splitCrossings(of wallIds: Set<String>, removed: inout [RemovedItem]) {
        var watched = wallIds
        // 한 번에 하나씩 나누므로 벽 수에 비례한 상한을 둬, 어긋난 도면에서도 끝나게 한다
        for _ in 0..<(walls.count * 4 + 16) {
            guard let contact = firstContact(involving: watched) else { return }
            let before = Set(walls.map(\.id))
            switch contact {
            case .cross(let first, let second, let point):
                guard let vertexId = splitWall(first, at: point, removed: &removed) else { return }
                _ = splitWall(second, at: point, reusing: vertexId, removed: &removed)
            case .touch(let wallId, let point, let vertexId):
                _ = splitWall(wallId, at: point, reusing: vertexId, removed: &removed)
            }
            watched.formUnion(Set(walls.map(\.id)).subtracting(before))
        }
    }

    /// 벽이 서로 만나는 자리
    private enum WallContact {
        /// 두 벽이 서로의 안쪽에서 가로지름
        case cross(first: String, second: String, point: SIMD2<Double>)
        /// 꼭짓점 하나가 벽 안쪽에 닿음. 그 벽을 이 꼭짓점에서 나눈다
        case touch(wallId: String, point: SIMD2<Double>, vertexId: String)
    }

    /// watched의 벽과 다른 벽이 만나는 자리 하나. 없으면 nil
    private func firstContact(involving watched: Set<String>) -> WallContact? {
        let pos = vertexPoints
        let eps = WallMoveRules.eps
        func isInside(_ point: SIMD2<Double>, of line: WallLine) -> Bool {
            let along = ((point - line.start) * line.direction).sum()
            return line.distance(to: point) < eps && along > eps && along < line.length - eps
        }
        for id in watched {
            guard let wall = wall(id: id), let wallLine = self.line(of: wall), wallLine.length > eps else { continue }
            for other in walls where other.id != id {
                guard let otherLine = self.line(of: other), otherLine.length > eps else { continue }
                if let crossing = Self.crossingPoint(wallLine, otherLine) {
                    return .cross(first: id, second: other.id, point: crossing)
                }
                for endId in [other.startVertex, other.endVertex] where endId != wall.startVertex && endId != wall.endVertex {
                    if let point = pos[endId], isInside(point, of: wallLine) { return .touch(wallId: id, point: point, vertexId: endId) }
                }
                for endId in [wall.startVertex, wall.endVertex] where endId != other.startVertex && endId != other.endVertex {
                    if let point = pos[endId], isInside(point, of: otherLine) { return .touch(wallId: other.id, point: point, vertexId: endId) }
                }
            }
        }
        return nil
    }
}

// 3) 겹친 벽 합치기
extension PlanData {
    /// 같은 두 꼭짓점을 잇는 벽이 둘 이상이면 하나만 남긴다. 이번에 편집한 벽(touched)이 아닌 원래 벽을 남기고, 지우는 벽에 달린 것은 남는 벽으로 옮긴다.
    /// 달린 것을 받은 벽의 id들을 돌려준다 (이어서 fitOpenings로 맞춘다)
    mutating func mergeOverlappingWalls(favoring touched: Set<String>) -> Set<String> {
        var receivers = Set<String>()
        var keptByPair: [Set<String>: String] = [:]
        let ordered = walls.filter { !touched.contains($0.id) } + walls.filter { touched.contains($0.id) }
        for wall in ordered {
            let pair: Set<String> = [wall.startVertex, wall.endVertex]
            guard pair.count == 2 else { continue }
            guard let keptId = keptByPair[pair] else {
                keptByPair[pair] = wall.id
                continue
            }
            guard let kept = self.wall(id: keptId), let keptLine = line(of: kept), let droppedLine = line(of: wall) else { continue }
            let isSameDirection = kept.startVertex == wall.startVertex
            for index in doorWindows.indices where doorWindows[index].wallId == wall.id {
                let place = droppedLine.point(along: doorWindows[index].centerAlongWall)
                doorWindows[index].wallId = keptId
                doorWindows[index].centerAlongWall = ((place - keptLine.start) * keptLine.direction).sum()
            }
            for index in wallFixtures.indices where wallFixtures[index].wallId == wall.id {
                let place = droppedLine.point(along: wallFixtures[index].positionAlongWall)
                wallFixtures[index].wallId = keptId
                wallFixtures[index].positionAlongWall = ((place - keptLine.start) * keptLine.direction).sum()
                if !isSameDirection { wallFixtures[index].face = wallFixtures[index].face == .left ? .right : .left }
            }
            walls.removeAll { $0.id == wall.id }
            receivers.insert(keptId)
        }
        return receivers
    }

    /// 길이가 0이 된 벽을 지우고(달린 것도 지워 removed에 적는다) 양 끝 꼭짓점을 하나로 합친다
    mutating func collapseZeroLengthWalls(among wallIds: Set<String>, removed: inout [RemovedItem]) {
        for id in wallIds {
            guard let wall = wall(id: id), let line = line(of: wall), line.length < WallMoveRules.eps else { continue }
            removeAttached(toWall: id, removed: &removed)
            walls.removeAll { $0.id == id }
            guard wall.startVertex != wall.endVertex else { continue }
            mergeVertex(wall.startVertex, into: wall.endVertex)
        }
    }

    /// 꼭짓점 gone을 꼭짓점 keep으로 합친다. gone을 쓰던 벽은 keep을 쓰게 된다
    mutating func mergeVertex(_ gone: String, into keep: String) {
        for index in walls.indices {
            if walls[index].startVertex == gone { walls[index].startVertex = keep }
            if walls[index].endVertex == gone { walls[index].endVertex = keep }
        }
        vertices.removeAll { $0.id == gone }
    }

    /// 어느 벽도 쓰지 않는 꼭짓점을 뺀다. 편집 전부터 있던 꼭짓점(keeping)은 건드리지 않는다
    mutating func removeUnusedVertices(keeping original: Set<String>) {
        let used = Set(walls.flatMap { [$0.startVertex, $0.endVertex] })
        vertices.removeAll { !used.contains($0.id) && !original.contains($0.id) }
    }
}

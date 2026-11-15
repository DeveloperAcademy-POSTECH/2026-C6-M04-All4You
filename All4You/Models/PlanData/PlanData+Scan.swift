// 공간 스캔 결과(ScanSurface)를 도면(PlanData)으로 바꾸기
//
// 1) 바닥 높이  2) 벽 양 끝점  3) 가장 긴 벽이 가로가 되게 돌리고, 조금 비뚤어진 벽은 가로·세로로 바로잡기
// 4) 스캔한 면은 방 안쪽 면이라 벽을 바깥으로 두께/2 밀고, 모서리는 이웃 벽 선과의 교점으로 잇기
// 5) 도면 왼쪽 위에 여백을 두고 옮기기 (벽 끝과 가구 모서리가 모두 여백 안쪽에 오게)  6) 가까운 끝점을 꼭짓점 하나로 합치기  7) 문·창문·개구부를 벽에 붙이기
// 8) 방 나누기 (PlanData+ScanRooms)  9) 물체를 사각형 가구로
//
// 벽이 하나도 없는 스캔은 바닥 윤곽을 가상 경계선(isVirtual)으로 삼아 바닥마다 방 하나를 만든다 (겹치는 바닥은 가장 넓은 것만).
// 이때 4)의 바깥으로 밀기와 7)의 문·창문 붙이기는 하지 않는다 (밀 벽도, 붙일 벽도 없음)

import Foundation
import simd

extension PlanData {
    /// 스캔한 면·방 종류·물체로 도면을 만든다. 벽이 없으면 바닥 윤곽으로 방을 만들고, 바닥 윤곽으로도 방이 안 되면 빈 도면
    init(scanSurfaces surfaces: [ScanSurface], sections: [ScanSection] = [], objects: [ScanObject] = []) {
        self = Self.converted(scanSurfaces: surfaces, sections: sections, objects: objects).plan
    }

    /// 도면과, 원본과 맞춰 본 기록(빠진 요소·벽 끝점이 움직인 거리)을 함께 돌려준다
    static func converted(
        scanSurfaces surfaces: [ScanSurface],
        sections: [ScanSection] = [],
        objects: [ScanObject] = []
    ) -> (plan: PlanData, report: ScanConversionReport) {
        var report = ScanConversionReport()
        for surface in surfaces {
            if let kind = ScanConversionReport.Kind(surface.kind) { report.sourceCounts[kind, default: 0] += 1 }
        }
        report.sourceCounts[.furniture] = objects.count
        // 위치·크기에 NaN·무한대가 든 면·물체는 하나 때문에 모든 꼭짓점이 NaN이 되므로 빼고 기록한다
        for surface in surfaces where !surface.isFinite {
            if let kind = ScanConversionReport.Kind(surface.kind) { report.omit(kind, surface.id, .invalidNumber) }
        }
        for _ in 0..<objects.filter({ !$0.isFinite }).count { report.omit(.furniture, nil, .invalidNumber) }

        var plan = PlanData.empty
        plan.fillFromScan(
            surfaces: surfaces.filter(\.isFinite),
            sections: sections.filter { $0.center.x.isFinite && $0.center.y.isFinite && $0.center.z.isFinite },
            objects: objects.filter(\.isFinite),
            report: &report
        )
        report.planCounts[.wall] = plan.walls.filter { !$0.isVirtual }.count
        for kind in [DoorWindowKind.door, .window, .passage] {
            let reportKind: ScanConversionReport.Kind = switch kind {
            case .door: .door
            case .window: .window
            default: .opening
            }
            report.planCounts[reportKind] = plan.doorWindows.filter { $0.kind == kind }.count
        }
        report.planCounts[.furniture] = plan.furniture?.count ?? 0
        return (plan, report)
    }

    /// 변환 본체. 이미 NaN을 걸러 낸 값만 받는다
    private mutating func fillFromScan(
        surfaces: [ScanSurface],
        sections: [ScanSection],
        objects: [ScanObject],
        report: inout ScanConversionReport
    ) {
        self = .empty
        let wallSurfaces = surfaces.filter { $0.kind == .wall && $0.width >= ScanRule.minWallLength }
        let usesFloorOutline = wallSurfaces.isEmpty
        for surface in surfaces where surface.kind == .wall && surface.width < ScanRule.minWallLength {
            report.omit(.wall, surface.id, .tooShort)
        }

        // 1) 바닥 높이: 바닥 면, 없으면 벽 아래 끝 중 가장 낮은 곳
        let floorY = surfaces.first { $0.kind == .floor }?.center.y
            ?? wallSurfaces.map { $0.center.y - $0.height / 2 }.min() ?? 0

        // 2) 벽 양 끝점 (바닥면 x, z). 벽이 없으면 바닥 윤곽의 변
        let raw = usesFloorOutline
            ? ScanImport.floorOutline(of: surfaces)
            : wallSurfaces.map { surface in
                let center = SIMD2(surface.center.x, surface.center.z)
                let half = surface.widthAxis * (surface.width / 2)
                return Segment(a: center - half, b: center + half)
            }
        guard !raw.isEmpty else { return }

        // 3) 돌리고 바로잡기
        let rotation = ScanImport.rotation(of: raw)
        let rotated = raw.map { ScanImport.squared(Segment(a: rotation.apply($0.a), b: rotation.apply($0.b))) }

        // 4) 바깥으로 밀고 모서리 잇기. 바닥 윤곽은 벽이 아니라 밀지 않는다
        let lines = ScanImport.joinedCorners(usesFloorOutline ? rotated : ScanImport.pushedOutward(rotated), original: rotated)

        // 5) 왼쪽 위 여백. 벽 끝뿐 아니라 가구 모서리도 넣는다 (스캔이 덜 닫혀 가구가 벽 밖에 있어도 도면 밖(음수 좌표)으로 나가지 않게)
        let furnitureCorners = objects.flatMap { object in
            let axis = rotation.apply(object.widthAxis)
            let angle = ScanImport.squaredAngle(atan2(axis.y, axis.x))
            let along = SIMD2(cos(angle), sin(angle)) * (max(ScanRule.minFurnitureSize, object.width) / 2)
            let across = SIMD2(-sin(angle), cos(angle)) * (max(ScanRule.minFurnitureSize, object.depth) / 2)
            let center = rotation.apply(SIMD2(object.center.x, object.center.z))
            return [center + along + across, center + along - across, center - along + across, center - along - across]
        }
        let lowest = (lines.flatMap { [$0.a, $0.b] } + furnitureCorners)
            .reduce(SIMD2(Double.infinity, .infinity)) { simd_min($0, $1) }
        let shift = SIMD2(repeating: ScanRule.margin) - lowest
        let shifted = lines.map { Segment(a: $0.a + shift, b: $0.b + shift) }
        // 원본 벽 끝점(돌리고 옮긴 자리)에서 보정으로 얼마나 움직였는지 잰다. 가상 경계선은 보정이 없어 재지 않는다
        if !usesFloorOutline {
            for (original, moved) in zip(raw, shifted) {
                let before = [rotation.apply(original.a) + shift, rotation.apply(original.b) + shift]
                report.maxWallShift = max(report.maxWallShift, simd_distance(before[0], moved.a), simd_distance(before[1], moved.b))
            }
        }
        func planPoint(_ world: SIMD3<Double>) -> SIMD2<Double> {
            rotation.apply(SIMD2(world.x, world.z)) + shift
        }
        // 같은 회전·이동을 남겨, 스캔 중 찍은 사진의 카메라 위치를 같은 도면 좌표로 옮긴다
        scanAlignment = ScanAlignment(angle: rotation.angle, shift: shift, floorHeight: floorY)

        // 6) 꼭짓점 합치기
        let graph = ScanImport.mergedVertices(shifted)
        vertices = graph.points.enumerated().map { Vertex(id: "v\($0.offset + 1)", x: $0.element.x, y: $0.element.y) }
        var wallIdOfSurface: [UUID: String] = [:]
        var wallIdOfIndex: [Int: String] = [:]
        // 방 나누기에서 사라진 벽·문·창문을 찾으려고 만든 id가 어느 원본에서 왔는지 남긴다
        var surfaceOfWallId: [String: UUID] = [:]
        var surfaceOfDoorId: [String: (id: UUID, kind: ScanConversionReport.Kind)] = [:]
        for (index, ends) in graph.ends.enumerated() {
            guard let ends else {
                if !usesFloorOutline {
                    report.omit(.wall, wallSurfaces[index].id, graph.keptIndex[index] == nil ? .absorbed : .overlapped)
                }
                continue
            }
            let id = "w\(walls.count + 1)"
            wallIdOfIndex[index] = id
            if usesFloorOutline {
                // 가상 경계선: 그리지 않는 벽이라 두께·높이가 없다
                walls.append(Wall(
                    id: id,
                    startVertex: vertices[ends.start].id,
                    endVertex: vertices[ends.end].id,
                    thickness: 0,
                    height: 0,
                    isVirtual: true
                ))
                continue
            }
            let surface = wallSurfaces[index]
            wallIdOfSurface[surface.id] = id
            surfaceOfWallId[id] = surface.id
            walls.append(Wall(
                id: id,
                startVertex: vertices[ends.start].id,
                endVertex: vertices[ends.end].id,
                thickness: ScanRule.wallThickness,
                height: max(ScanRule.minWallHeight, surface.center.y + surface.height / 2 - floorY),
                isVirtual: false
            ))
        }
        // 같은 꼭짓점 쌍이 되어 벽으로 남지 못한 면(같은 벽을 두 번 스캔함)에 붙은 문·창문은 남은 벽에 붙인다
        for (index, kept) in graph.keptIndex.enumerated() where !usesFloorOutline {
            guard let kept, let id = wallIdOfIndex[kept] else { continue }
            wallIdOfSurface[wallSurfaces[index].id] = id
        }

        // 7) 문·창문·개구부: 속한 벽, 없으면 가까운 벽에 붙인다 (벽이 없으면 붙일 곳이 없어 기록만 남긴다)
        for surface in surfaces where [.door, .window, .opening].contains(surface.kind) {
            guard !usesFloorOutline else {
                if let kind = ScanConversionReport.Kind(surface.kind) { report.omit(kind, surface.id, .noWallToAttach) }
                continue
            }
            let point = planPoint(surface.center)
            let wall = surface.parentId.flatMap { wallIdOfSurface[$0] }.flatMap { self.wall(id: $0) }
                ?? walls.min { distance(from: point, to: $0) < distance(from: point, to: $1) }
                    .flatMap { distance(from: point, to: $0) <= ScanRule.openingSearchDistance ? $0 : nil }
                ?? wallBeneath(point)
            guard let wall, let line = line(of: wall) else {
                if let kind = ScanConversionReport.Kind(surface.kind) { report.omit(kind, surface.id, .noWallToAttach) }
                continue
            }
            let kind: DoorWindowKind = switch surface.kind {
            case .door: .door
            case .window: .window
            default: .passage
            }
            let width = min(surface.width, line.length)
            let along = simd_dot(point - line.start, line.direction)
            let bottom = max(0, surface.center.y - surface.height / 2 - floorY)
            let sill = kind == .window ? bottom : 0
            let doorId = "d\(doorWindows.count + 1)"
            if let reportKind = ScanConversionReport.Kind(surface.kind) { surfaceOfDoorId[doorId] = (surface.id, reportKind) }
            doorWindows.append(DoorWindow(
                id: doorId,
                wallId: wall.id,
                kind: kind,
                centerAlongWall: min(max(along, width / 2), line.length - width / 2),
                width: width,
                sillHeight: sill,
                // 문·개구부는 바닥부터 위 끝까지
                height: max(ScanRule.minOpeningHeight, min(surface.height + (kind == .window ? 0 : bottom), wall.height - sill))
            ))
        }

        // 8) 떠 있는 벽 끝을 잇고 방을 찾는다
        addScanRooms(sections: sections.map { (name: $0.name, point: planPoint($0.center)) })
        // 방을 나누며 꼭짓점이 합쳐져 사라진 벽(겹침)과 문·창문(두 끝이 같아진 벽에 붙었던 것)을 기록한다
        for (wallId, surfaceId) in surfaceOfWallId where wall(id: wallId) == nil {
            report.omit(.wall, surfaceId, .mergedWhileSplitting)
        }
        for (doorId, source) in surfaceOfDoorId where !doorWindows.contains(where: { $0.id == doorId }) {
            report.omit(source.kind, source.id, .mergedWhileSplitting)
        }
        // 바닥 윤곽이 너무 작아 방이 안 되면 경계선만 남은 도면이 되므로 빈 도면으로 돌려준다
        if usesFloorOutline, rooms.isEmpty {
            self = .empty
            return
        }

        // 9) 물체 → 사각형 가구. 벽처럼 조금 비뚤어진 가구는 가로·세로로 바로잡는다
        furniture = objects.enumerated().map { index, object in
            let axis = rotation.apply(object.widthAxis)
            return Furniture(
                id: "u\(index + 1)",
                label: Furniture.label(forCategory: object.category),
                category: object.category,
                shape: .rectangle,
                center: planPoint(object.center),
                width: max(ScanRule.minFurnitureSize, object.width),
                depth: max(ScanRule.minFurnitureSize, object.depth),
                rotation: ScanImport.squaredAngle(atan2(axis.y, axis.x)),
                height: max(ScanRule.minFurnitureSize, object.height),
                elevation: max(0, object.center.y - object.height / 2 - floorY)
            )
        }
    }

    /// 점을 벽 위로 내렸을 때 벽 안(양 끝 사이)에 들어오는 벽 중 가장 가까운 벽. 거리 제한은 없다.
    /// 속한 벽도 가까운 벽도 없는 문·창문을 살리되, 벽 옆으로 한참 벗어난 곳에는 붙이지 않는다
    private func wallBeneath(_ point: SIMD2<Double>) -> Wall? {
        walls
            .compactMap { wall -> (wall: Wall, distance: Double)? in
                guard let line = line(of: wall) else { return nil }
                let along = simd_dot(point - line.start, line.direction)
                guard along >= 0, along <= line.length else { return nil }
                return (wall, line.distance(to: point))
            }
            .min { $0.distance < $1.distance }?
            .wall
    }

    /// 점에서 벽 선분까지 거리. 벽을 찾지 못하면 무한대
    private func distance(from point: SIMD2<Double>, to wall: Wall) -> Double {
        line(of: wall)?.distance(to: point) ?? .infinity
    }
}

/// 벽 하나의 양 끝 (도면 좌표)
private struct Segment {
    var a: SIMD2<Double>
    var b: SIMD2<Double>

    var length: Double { simd_distance(a, b) }
    var angle: Double { atan2(b.y - a.y, b.x - a.x) }
}

/// 스캔 좌표를 도면 방향으로 돌리는 회전
private struct ScanRotation {
    let angle: Double

    func apply(_ p: SIMD2<Double>) -> SIMD2<Double> {
        SIMD2(p.x * cos(angle) - p.y * sin(angle), p.x * sin(angle) + p.y * cos(angle))
    }
}

/// 변환 단계마다 쓰는 계산
private enum ScanImport {
    /// 방의 주축을 가로로 돌리는 회전.
    /// 벽은 서로 90°씩 돌아가 있으므로 각을 4배 하면 같은 축의 벽들이 같은 방향을 가리킨다. 길이로 가중한 4배각 평균을 4로 나누면 방 전체가 기울어진 정도가 된다.
    /// 주축은 90°마다 같으므로, 그중 가장 긴 벽에 가까운 쪽을 골라 그 벽이 가로가 되게 한다
    static func rotation(of segments: [Segment]) -> ScanRotation {
        var sum = SIMD2<Double>.zero
        for segment in segments {
            sum += segment.length * SIMD2(cos(4 * segment.angle), sin(4 * segment.angle))
        }
        let axis = atan2(sum.y, sum.x) / 4
        let longest = segments.max { $0.length < $1.length }!
        let quarter = ((longest.angle - axis) / (.pi / 2)).rounded()
        return ScanRotation(angle: -(axis + quarter * .pi / 2))
    }

    /// 벽이 없는 스캔에서 쓸 바닥 윤곽의 변들. 바닥마다 방 하나가 된다.
    /// 서로 겹치는 바닥은 가장 넓은 것만 쓴다 (겹치거나 가로지르는 변은 방 찾기가 깨진다). 방이 될 수 없이 좁은 바닥과 너무 짧은 변은 버린다
    static func floorOutline(of surfaces: [ScanSurface]) -> [Segment] {
        let floors = surfaces
            .filter { $0.kind == .floor && $0.corners.count >= 3 }
            .map { $0.corners }
            .filter { area(of: $0) >= ScanRule.minFloorArea }
            .sorted { area(of: $0) > area(of: $1) }
        var accepted: [[SIMD2<Double>]] = []
        for corners in floors where !accepted.contains(where: { overlaps($0, corners) }) {
            accepted.append(corners)
        }
        return accepted.flatMap { corners in
            corners.indices
                .map { Segment(a: corners[$0], b: corners[($0 + 1) % corners.count]) }
                .filter { $0.length >= ScanRule.minWallLength }
        }
    }

    /// 다각형 넓이 (신발끈 공식)
    private static func area(of corners: [SIMD2<Double>]) -> Double {
        var sum = 0.0
        for index in corners.indices {
            let current = corners[index]
            let next = corners[(index + 1) % corners.count]
            sum += current.x * next.y - next.x * current.y
        }
        return abs(sum) / 2
    }

    /// 두 다각형이 겹치면 true. 변을 같이 쓰며 맞닿기만 한 것은 겹침이 아니다
    private static func overlaps(_ first: [SIMD2<Double>], _ second: [SIMD2<Double>]) -> Bool {
        // 서로의 안에 든 꼭짓점 (변 위에 놓인 꼭짓점이 안쪽으로 잘못 세이지 않게 자기 가운데 쪽으로 조금 옮겨 본다)
        for (polygon, other) in [(first, second), (second, first)] {
            let center = polygon.reduce(.zero, +) / Double(polygon.count)
            if contains(other, center) { return true }
            for corner in polygon where contains(other, corner + (center - corner) * 0.02) { return true }
        }
        // 변이 서로 가로지름
        for i in first.indices {
            for j in second.indices where crosses(first[i], first[(i + 1) % first.count], second[j], second[(j + 1) % second.count]) {
                return true
            }
        }
        return false
    }

    /// 점이 다각형 안에 있으면 true (반직선이 변을 홀수 번 만남)
    private static func contains(_ polygon: [SIMD2<Double>], _ point: SIMD2<Double>) -> Bool {
        var inside = false
        for i in polygon.indices {
            let a = polygon[i]
            let b = polygon[(i + 1) % polygon.count]
            if (a.y > point.y) != (b.y > point.y), point.x < (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x {
                inside.toggle()
            }
        }
        return inside
    }

    /// 두 선분이 서로의 안쪽에서 엇갈리면 true (끝이 닿기만 한 것은 아님)
    private static func crosses(_ a: SIMD2<Double>, _ b: SIMD2<Double>, _ c: SIMD2<Double>, _ d: SIMD2<Double>) -> Bool {
        func side(_ p: SIMD2<Double>, _ q: SIMD2<Double>, _ r: SIMD2<Double>) -> Double {
            (q.x - p.x) * (r.y - p.y) - (q.y - p.y) * (r.x - p.x)
        }
        let eps = 1e-9
        let d1 = side(a, b, c), d2 = side(a, b, d), d3 = side(c, d, a), d4 = side(c, d, b)
        return ((d1 > eps && d2 < -eps) || (d1 < -eps && d2 > eps)) && ((d3 > eps && d4 < -eps) || (d3 < -eps && d4 > eps))
    }

    /// 가로·세로에서 조금 비뚤어진 벽은 가운데를 축으로 돌려 가로·세로로 맞춘다
    static func squared(_ segment: Segment) -> Segment {
        let target = squaredAngle(segment.angle)
        let center = (segment.a + segment.b) / 2
        let half = SIMD2(cos(target), sin(target)) * (segment.length / 2)
        return Segment(a: center - half, b: center + half)
    }

    /// 가로·세로에서 조금 비뚤어진 각(라디안)은 가장 가까운 직각으로. 많이 비뚤어졌으면 그대로
    static func squaredAngle(_ angle: Double) -> Double {
        let target = (angle / (.pi / 2)).rounded() * (.pi / 2)
        return abs(angle - target) <= ScanRule.squareLimit ? target : angle
    }

    /// 스캔한 면은 방 안쪽 면이다. 벽 선을 방 바깥쪽으로 두께/2 밀어 벽의 안쪽 면이 스캔한 면과 겹치게 한다.
    /// 어느 쪽이 방 안인지는 벽 가운데에서 양쪽으로 반직선을 쏴서, 다른 벽을 홀수 번 만나는 쪽으로 본다 (L자 방의 안쪽 모서리도 맞게).
    /// 양쪽 다 방 안이면 방 사이 칸막이라 밀지 않고, 양쪽 다 아니면(스캔이 덜 닫힘) 전체 가운데 반대쪽으로 민다
    static func pushedOutward(_ segments: [Segment]) -> [Segment] {
        let center = segments.map { ($0.a + $0.b) / 2 }.reduce(.zero, +) / Double(segments.count)
        return segments.indices.map { index in
            let segment = segments[index]
            let middle = (segment.a + segment.b) / 2
            let direction = simd_normalize(segment.b - segment.a)
            let normal = SIMD2(-direction.y, direction.x)
            let insideAlongNormal = crossesOddTimes(from: middle + normal * 0.01, toward: normal, skipping: index, in: segments)
            let insideAgainstNormal = crossesOddTimes(from: middle - normal * 0.01, toward: -normal, skipping: index, in: segments)
            let outward: SIMD2<Double>
            switch (insideAlongNormal, insideAgainstNormal) {
            case (true, false): outward = -normal
            case (false, true): outward = normal
            case (true, true): return segment
            case (false, false): outward = simd_dot(normal, middle - center) < 0 ? -normal : normal
            }
            let offset = outward * ScanRule.wallThickness / 2
            return Segment(a: segment.a + offset, b: segment.b + offset)
        }
    }

    /// 점에서 한 방향으로 쏜 반직선이 다른 벽을 홀수 번 만나면 true (그 점이 벽으로 둘러싸인 안쪽)
    private static func crossesOddTimes(from point: SIMD2<Double>, toward direction: SIMD2<Double>, skipping skipped: Int, in segments: [Segment]) -> Bool {
        var count = 0
        for (index, other) in segments.enumerated() where index != skipped {
            let edge = other.b - other.a
            let cross = direction.x * edge.y - direction.y * edge.x
            guard abs(cross) > 1e-9 else { continue }
            let diff = other.a - point
            // 반직선 위 거리와 벽 위 비율. 벽 끝점은 한쪽(시작)만 세서 모서리를 두 번 세지 않는다
            let along = (diff.x * edge.y - diff.y * edge.x) / cross
            let ratio = (diff.x * direction.y - diff.y * direction.x) / cross
            if along > 0, ratio >= 0, ratio < 1 { count += 1 }
        }
        return count % 2 == 1
    }

    /// 다른 벽 끝과 가까운 끝은 두 벽 선(밀어낸 선)의 교점으로 옮긴다. 가까운지는 밀기 전 위치로 본다
    static func joinedCorners(_ lines: [Segment], original: [Segment]) -> [Segment] {
        var joined = lines
        for i in lines.indices {
            for isStart in [true, false] {
                let end = isStart ? original[i].a : original[i].b
                let neighbor = original.indices
                    .filter { $0 != i }
                    .map { ($0, min(simd_distance(end, original[$0].a), simd_distance(end, original[$0].b))) }
                    .filter { $0.1 < ScanRule.cornerSearchDistance }
                    .min { $0.1 < $1.1 }
                guard let neighbor, let corner = intersection(lines[i], lines[neighbor.0]) else { continue }
                let current = isStart ? lines[i].a : lines[i].b
                guard simd_distance(corner, current) < ScanRule.cornerMoveLimit else { continue }
                if isStart { joined[i].a = corner } else { joined[i].b = corner }
            }
        }
        return joined
    }

    /// 두 직선의 교점. 나란하면 nil
    static func intersection(_ p: Segment, _ q: Segment) -> SIMD2<Double>? {
        let d1 = p.b - p.a
        let d2 = q.b - q.a
        let cross = d1.x * d2.y - d1.y * d2.x
        guard abs(cross) > 1e-9 else { return nil }
        let diff = q.a - p.a
        let s = (diff.x * d2.y - diff.y * d2.x) / cross
        return p.a + d1 * s
    }

    /// 가까운 끝점들을 꼭짓점 하나로 합친다. ends[i]는 벽 i의 시작·끝 꼭짓점 번호, 두 끝이 같은 꼭짓점이 되거나 이미 같은 벽이 있으면 nil.
    /// keptIndex[i]는 벽 i가 이미 있는 벽과 같은 꼭짓점 쌍이라 빠졌을 때 그 남은 벽의 번호 (두 끝이 같은 꼭짓점이 되어 빠졌으면 nil)
    static func mergedVertices(_ segments: [Segment]) -> (points: [SIMD2<Double>], ends: [(start: Int, end: Int)?], keptIndex: [Int?]) {
        var groups: [[SIMD2<Double>]] = []
        func group(of point: SIMD2<Double>) -> Int {
            if let found = groups.firstIndex(where: { members in
                simd_distance(members.reduce(.zero, +) / Double(members.count), point) < ScanRule.vertexMergeDistance
            }) {
                groups[found].append(point)
                return found
            }
            groups.append([point])
            return groups.count - 1
        }
        let pairs = segments.map { (group(of: $0.a), group(of: $0.b)) }
        var points = groups.map { $0.reduce(.zero, +) / Double($0.count) }

        // 합치면서 조금 어긋난 가로·세로 벽을 다시 반듯하게 (두 꼭짓점의 y나 x를 같게)
        for _ in 0..<2 {
            for (start, end) in pairs where start != end {
                let d = points[end] - points[start]
                if abs(d.y) < ScanRule.axisSnapTolerance, abs(d.x) > abs(d.y) {
                    let y = (points[start].y + points[end].y) / 2
                    points[start].y = y
                    points[end].y = y
                } else if abs(d.x) < ScanRule.axisSnapTolerance, abs(d.y) > abs(d.x) {
                    let x = (points[start].x + points[end].x) / 2
                    points[start].x = x
                    points[end].x = x
                }
            }
        }

        var firstOfPair: [[Int]: Int] = [:]
        var keptIndex = [Int?](repeating: nil, count: pairs.count)
        let ends: [(start: Int, end: Int)?] = pairs.enumerated().map { index, pair in
            let (start, end) = pair
            guard start != end else { return nil }
            let key = [min(start, end), max(start, end)]
            if let first = firstOfPair[key] {
                keptIndex[index] = first
                return nil
            }
            firstOfPair[key] = index
            return (start, end)
        }
        return (points, ends, keptIndex)
    }
}

/// 스캔 변환에 쓰는 값 (m)
private enum ScanRule {
    /// 벽 두께. 스캔은 두께를 주지 않는다
    static let wallThickness = 0.15
    /// 이보다 짧은 벽은 버린다
    static let minWallLength = 0.1
    /// 벽이 없는 스캔에서 이보다 좁은 바닥은 방으로 보지 않는다 (방 나누기의 최소 방 넓이와 같게, ㎡)
    static let minFloorArea = 0.5
    static let minWallHeight = 0.5
    static let minOpeningHeight = 0.1
    /// 도면 왼쪽 위 여백
    static let margin = 0.5
    /// 가로·세로에서 이 각도 안으로 비뚤어진 벽은 바로잡는다 (4°)
    static let squareLimit = 4 * Double.pi / 180
    /// 벽 끝에서 이 거리 안에 다른 벽 끝이 있으면 모서리로 잇는다
    static let cornerSearchDistance = 0.3
    /// 모서리로 이을 때 끝이 이보다 멀리 옮겨지면 잇지 않는다
    static let cornerMoveLimit = 0.6
    /// 이 거리 안의 끝점은 꼭짓점 하나로 합친다
    static let vertexMergeDistance = 0.1
    /// 합친 뒤 가로·세로 벽의 양 끝이 이만큼 안 어긋났으면 반듯하게 맞춘다
    static let axisSnapTolerance = 0.05
    /// 속한 벽이 없는 문·창문은 먼저 이 거리 안의 가장 가까운 벽에 붙인다 (없으면 벽 위로 내린 점이 벽 안에 드는 가장 가까운 벽)
    static let openingSearchDistance = 0.5
    /// 가구의 가로·세로·높이가 이보다 작으면 이 값으로 (너무 작아 고를 수 없는 가구를 막음)
    static let minFurnitureSize = 0.05
}

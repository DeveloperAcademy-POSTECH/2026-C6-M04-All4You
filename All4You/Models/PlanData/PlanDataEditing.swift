// 도면의 스탬프를 더하고 옮기고 돌리고 복제·삭제하고, 창문을 달고 크기를 바꾸고 지우는 계산. 화면은 도면 좌표만 넘기고, 저장 모양(벽 기준 위치·면 등)은 여기서 정한다

import Foundation

extension PlanData {
    /// 복제한 스탬프를 원래 것에서 떨어뜨리는 거리 (m). 사람·발화지점은 도면 오른쪽으로, 벽에 붙은 것은 벽을 따라
    /// TEMP: 복제 자리는 디자인 확인 전이라 임시로 정한 값
    fileprivate static let duplicateGap = 0.5
}

// 사람·발화지점
extension PlanData {
    /// 바닥 위 point(도면 좌표, m)에 사람·발화지점을 놓고 새 id를 돌려준다. 어디든 놓을 수 있다 (벽과 겹치거나 방 밖이어도).
    /// 사람은 늘 누운 자세로 놓는다
    @discardableResult
    mutating func addMarker(_ kind: MarkerKind, at point: SIMD2<Double>, scale: Double? = nil, ignitionCause: IgnitionCause? = nil, electricalKind: ElectricalKind? = nil) -> String {
        let marker = makeMarker(kind, at: point, scale: scale, ignitionCause: ignitionCause, electricalKind: electricalKind)
        markers.append(marker)
        return marker.id
    }

    /// 새로 놓을 사람·발화지점. 아직 도면에 넣지 않는다 (스케치 스탬프가 놓을 자리를 미리 살필 때도 쓴다).
    /// TEMP: 새 스탬프의 높이·방향은 디자인 확인 전이라 바닥(0m)·위쪽(0°)으로 둠
    func makeMarker(_ kind: MarkerKind, at point: SIMD2<Double>, scale: Double? = nil, ignitionCause: IgnitionCause? = nil, electricalKind: ElectricalKind? = nil) -> PlanMarker {
        PlanMarker(
            id: UUID().uuidString,
            kind: kind,
            position: point,
            height: kind.sitsOnFurniture ? surfaceHeight(at: point) : 0,
            yaw: 0,
            lying: kind == .person ? true : nil,
            scale: scale,
            ignitionCause: ignitionCause,
            electricalKind: electricalKind
        )
    }

    /// 사람·발화지점을 바닥 위 point(도면 좌표, m)로 옮긴다. 어디로든 옮길 수 있다
    mutating func moveMarker(id: String, to point: SIMD2<Double>) {
        updateMarker(id: id) { $0.position = point }
    }

    /// 사람·발화지점의 방향을 yaw(도)로 바꾼다. 0~360° 안으로 맞춘다
    mutating func rotateMarker(id: String, yaw: Double) {
        let degrees = yaw.truncatingRemainder(dividingBy: 360)
        updateMarker(id: id) { $0.yaw = degrees < 0 ? degrees + 360 : degrees }
    }

    /// 사람·발화지점을 같은 종류·방향·자세·크기로 오른쪽 옆에 하나 더 놓고 새 id를 돌려준다. 원래 것을 찾지 못하면 nil
    mutating func duplicateMarker(id: String) -> String? {
        guard let original = markers.first(where: { $0.id == id }) else { return nil }
        let position = original.position + SIMD2(Self.duplicateGap, 0)
        let copy = PlanMarker(
            id: UUID().uuidString,
            kind: original.kind,
            position: position,
            height: original.kind.sitsOnFurniture ? surfaceHeight(at: position) : original.height,
            yaw: original.yaw,
            lying: original.lying,
            scale: original.scale,
            ignitionCause: original.ignitionCause,
            electricalKind: original.electricalKind,
            kindNote: original.kindNote
        )
        markers.append(copy)
        return copy.id
    }

    /// 사람·발화지점의 크기 배율을 바꾼다. markerScaleRange 안으로 맞춘다
    mutating func resizeMarker(id: String, scale: Double) {
        let wanted = min(max(scale, Self.markerScaleRange.lowerBound), Self.markerScaleRange.upperBound)
        updateMarker(id: id) { $0.scale = wanted }
    }

    /// 표시 하나를 change대로 바꾼다
    private mutating func updateMarker(id: String, _ change: (inout PlanMarker) -> Void) {
        guard let index = markers.firstIndex(where: { $0.id == id }) else { return }
        var changed = markers[index]
        change(&changed)
        // 가구 위로 옮기면 가구 윗면 위로 올라오고, 바닥으로 옮기면 내려온다
        if changed.kind.sitsOnFurniture { changed.height = surfaceHeight(at: changed.position) }
        markers[index] = changed
    }

    /// 점 point 아래 가구 윗면의 바닥에서 높이 (m). 가구 위가 아니면 0, 가구가 겹쳐 있으면 가장 높은 것.
    /// 사람·발화지점이 가구 안에 묻히지 않고 가구 위에 올라오게 하는 높이다
    func surfaceHeight(at point: SIMD2<Double>) -> Double {
        (furniture ?? []).filter { $0.contains(point) }.map { $0.elevation + $0.height }.max() ?? 0
    }

    /// 가구를 놓거나 옮기거나 키우거나 지운 뒤, 가구 위에 놓인 사람·발화지점의 높이를 다시 맞춘다
    mutating func reseatMarkers() {
        for index in markers.indices where markers[index].kind.sitsOnFurniture {
            markers[index].height = surfaceHeight(at: markers[index].position)
        }
    }

    /// 사람·발화지점 크기 배율의 범위
    /// TEMP: 디자인 확인 전이라 임시로 정한 값 (기본의 0.2배 ~ 2.5배). 스탬프 기본 크기(StampDefaults)에 맞추면 사람이 0.5배보다 작아져서 하한을 낮췄다
    static let markerScaleRange = 0.2...2.5

    mutating func removeMarker(id: String) {
        markers.removeAll { $0.id == id }
    }
}

// 콘센트처럼 벽에 붙는 것
extension PlanData {
    /// 벽 wallId의 면 위 점 point(도면 좌표)와 바닥에서 높이 height(m)에 콘센트 같은 것을 붙이고 새 id를 돌려준다.
    /// 누른 쪽 면에 붙인다. 벽을 찾지 못하면 nil
    mutating func addWallFixture(_ kind: FixtureKind, wallId: String, at point: SIMD2<Double>, height: Double, electricalKind: ElectricalKind? = nil) -> String? {
        guard let spot = wallSpot(wallId: wallId, point: point, height: height) else { return nil }
        let fixture = WallFixture(
            id: UUID().uuidString,
            wallId: wallId,
            kind: kind,
            face: spot.face,
            positionAlongWall: spot.along,
            heightFromFloor: spot.height,
            electricalKind: electricalKind
        )
        wallFixtures.append(fixture)
        return fixture.id
    }

    /// 벽에 붙은 것을 같은 벽 면 위 점 point(도면 좌표)와 높이 height(m)로 옮긴다. 붙은 면은 그대로 둔다
    mutating func moveWallFixture(id: String, to point: SIMD2<Double>, height: Double) {
        guard let index = wallFixtures.firstIndex(where: { $0.id == id }),
              let spot = wallSpot(wallId: wallFixtures[index].wallId, point: point, height: height) else { return }
        wallFixtures[index].positionAlongWall = spot.along
        wallFixtures[index].heightFromFloor = spot.height
    }

    /// 벽에 붙은 것을 같은 벽·면·높이로 벽을 따라 옆에 하나 더 붙이고 새 id를 돌려준다. 벽 끝을 넘으면 반대쪽에 붙인다
    mutating func duplicateWallFixture(id: String) -> String? {
        guard let original = wallFixtures.first(where: { $0.id == id }),
              let wall = wall(id: original.wallId), let line = line(of: wall) else { return nil }
        let forward = original.positionAlongWall + Self.duplicateGap
        let along = forward <= line.length ? forward : max(original.positionAlongWall - Self.duplicateGap, 0)
        let copy = WallFixture(
            id: UUID().uuidString,
            wallId: original.wallId,
            kind: original.kind,
            face: original.face,
            positionAlongWall: along,
            heightFromFloor: original.heightFromFloor,
            electricalKind: original.electricalKind,
            kindNote: original.kindNote
        )
        wallFixtures.append(copy)
        return copy.id
    }

    mutating func removeWallFixture(id: String) {
        wallFixtures.removeAll { $0.id == id }
    }

    /// 도면 점과 높이를 벽 기준 자리로 바꾼다. 벽을 따라간 위치는 벽 안으로, 높이는 벽 높이 안으로 맞춘다
    private func wallSpot(wallId: String, point: SIMD2<Double>, height: Double) -> (face: WallFace, along: Double, height: Double)? {
        guard let wall = wall(id: wallId), let line = line(of: wall) else { return nil }
        let offset = point - line.start
        let along = (offset * line.direction).sum()
        let side = (offset * line.leftNormal).sum()
        return (
            face: side >= 0 ? .left : .right,
            along: min(max(along, 0), line.length),
            height: min(max(height, 0), wall.height)
        )
    }
}

// 공간 이름
extension PlanData {
    /// 방 이름을 바꾼다. 앞뒤 빈칸을 빼고 비어 있으면 바꾸지 않는다
    mutating func renameRoom(id: String, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = rooms.firstIndex(where: { $0.id == id }) else { return }
        rooms[index].name = trimmed
    }

    /// point(도면 좌표, m) 자리에 "새 공간" 라벨을 달고 새 id를 돌려준다. 어디든 달 수 있다.
    /// 영역(닫힌 칸·바닥)은 저장하지 않고 라벨 자리에서 그때그때 계산한다
    @discardableResult
    mutating func addRoom(at point: SIMD2<Double>) -> String {
        let id = UUID().uuidString
        rooms.append(Room(id: id, name: RoomCopy.newRoomName, labelX: point.x, labelY: point.y))
        return id
    }

    /// 방(공간 이름)을 지운다. 벽은 그대로 둔다.
    /// 그 방에 놓였던 사진·메모는 장소가 없어진다
    mutating func removeRoom(id: String) {
        rooms.removeAll { $0.id == id }
    }

    /// 방 이름을 보여 줄 자리를 point(도면 좌표, m)로 옮긴다. 어디로든 옮길 수 있다
    mutating func moveRoomLabel(id: String, to point: SIMD2<Double>) {
        guard let index = rooms.firstIndex(where: { $0.id == id }) else { return }
        rooms[index].labelX = point.x
        rooms[index].labelY = point.y
    }
}

// 벽 한 줄
extension PlanData {
}

// 스캔한 바닥
extension PlanData {
    /// 스캔한 바닥을 지운다. 벽·가구·공간 라벨은 그대로 둔다
    mutating func removeFloor(id: String) {
        floors?.removeAll { $0.id == id }
        if floors?.isEmpty == true { floors = nil }
    }
}

// 창문
extension PlanData {
    /// 새 창문 크기 (m)
    /// TEMP: 디자인 확인 전이라 흔한 창문 크기로 임시로 정한 값
    fileprivate static let newWindowWidth = 1.0
    fileprivate static let newWindowHeight = 1.2
    fileprivate static let newWindowSillHeight = 0.9
    /// 새 문 크기 (m). 문은 바닥부터 시작한다
    /// TEMP: 디자인 확인 전이라 흔한 방문 크기로 임시로 정한 값
    fileprivate static let newDoorWidth = 0.9
    fileprivate static let newDoorHeight = 2.0
    /// 창문·문 폭·높이의 가장 작은 값 (m)
    static let minimumWindowSize = 0.2

    /// 벽 wallId 위 점 point(도면 좌표)를 가운데로 창문을 달고 새 id를 돌려준다. addOpening(.window, …)과 같다
    mutating func addWindow(wallId: String, at point: SIMD2<Double>) -> String? {
        addOpening(.window, wallId: wallId, at: point)
    }

    /// 벽 wallId 위 점 point(도면 좌표)를 가운데로 창문이나 문을 달고 새 id를 돌려준다.
    /// 벽 끝이나 옆 문·창문과 겹치면 그 사이 빈 칸 안으로 줄이거나 밀어 넣는다. 빈 칸이 너무 좁거나 벽을 찾지 못하면 nil
    mutating func addOpening(_ kind: DoorWindowKind, wallId: String, at point: SIMD2<Double>, width wantedWidth: Double? = nil) -> String? {
        guard let wall = wall(id: wallId), let line = line(of: wall) else { return nil }
        let isDoor = kind == .door
        let newWidth = wantedWidth ?? (isDoor ? Self.newDoorWidth : Self.newWindowWidth)
        let sillHeight = isDoor ? 0 : Self.newWindowSillHeight
        let newHeight = isDoor ? Self.newDoorHeight : Self.newWindowHeight
        let along = ((point - line.start) * line.direction).sum()
        let gap = openingGap(on: wall, line: line, around: along, excluding: nil)
        let width = min(newWidth, gap.upperBound - gap.lowerBound)
        let height = min(newHeight, wall.height - sillHeight)
        guard width >= Self.minimumWindowSize, height >= Self.minimumWindowSize else { return nil }
        let window = DoorWindow(
            id: UUID().uuidString,
            wallId: wallId,
            kind: kind,
            centerAlongWall: min(max(along, gap.lowerBound + width / 2), gap.upperBound - width / 2),
            width: width,
            sillHeight: sillHeight,
            height: height
        )
        doorWindows.append(window)
        return window.id
    }

    /// 창문 테두리 edge 하나를 옮겨 폭·높이를 바꾼다. 반대쪽 테두리는 그대로 둔다.
    /// along = 벽 시작점에서 거리 (m, 벽 방향 테두리), height = 바닥에서 높이 (m, 위·아래 테두리).
    /// 가장 작은 크기보다 작아지거나 벽 끝·벽 높이·옆 문·창문을 넘지 않게 맞춘다
    mutating func resizeWindow(id: String, edge: WindowEdge, along: Double, height: Double) {
        guard let index = doorWindows.firstIndex(where: { $0.id == id }),
              let wall = wall(id: doorWindows[index].wallId), let line = line(of: wall) else { return }
        let window = doorWindows[index]
        let gap = openingGap(on: wall, line: line, around: window.centerAlongWall, excluding: id)
        let minimum = Self.minimumWindowSize
        var start = window.centerAlongWall - window.width / 2
        var end = window.centerAlongWall + window.width / 2
        var bottom = window.sillHeight
        var top = window.sillHeight + window.height
        switch edge {
        case .wallStart: start = min(max(along, gap.lowerBound), end - minimum)
        case .wallEnd: end = max(min(along, gap.upperBound), start + minimum)
        case .bottom: bottom = min(max(height, 0), top - minimum)
        case .top: top = max(min(height, wall.height), bottom + minimum)
        }
        doorWindows[index].centerAlongWall = (start + end) / 2
        doorWindows[index].width = end - start
        doorWindows[index].sillHeight = bottom
        doorWindows[index].height = top - bottom
    }

    mutating func removeDoorWindow(id: String) {
        doorWindows.removeAll { $0.id == id }
    }

    /// 벽 위에서 along(벽 시작점에서 거리, m)이 들어 있는 빈 칸. 벽 끝과 다른 문·창문(id가 excluding인 것은 뺌)이 경계다.
    /// along이 다른 문·창문 안이면 길이 0인 칸
    private func openingGap(on wall: Wall, line: WallLine, around along: Double, excluding id: String?) -> ClosedRange<Double> {
        var lower = 0.0
        var upper = line.length
        for other in doorWindows where other.wallId == wall.id && other.id != id {
            let otherStart = other.centerAlongWall - other.width / 2
            let otherEnd = other.centerAlongWall + other.width / 2
            if otherEnd <= along {
                lower = max(lower, otherEnd)
            } else if otherStart >= along {
                upper = min(upper, otherStart)
            } else {
                return along...along
            }
        }
        return lower...max(lower, upper)
    }
}

/// 창문의 네 테두리. 시작·끝은 화면 왼쪽·오른쪽이 아니라 벽 시작점 쪽·끝점 쪽
enum WindowEdge: CaseIterable {
    case wallStart
    case wallEnd
    case top
    case bottom
}

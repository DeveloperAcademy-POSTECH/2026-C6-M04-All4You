// 도면의 스탬프를 더하고 옮기고 돌리고 복제·삭제하고, 창문을 달고 크기를 바꾸고 지우는 계산. 화면은 도면 좌표만 넘기고, 저장 모양(벽 기준 위치·면 등)은 여기서 정한다

import Foundation

extension PlanData {
    /// 복제한 스탬프를 원래 것에서 떨어뜨리는 거리 (m). 사람·발화지점은 도면 오른쪽으로, 벽에 붙은 것은 벽을 따라
    /// TEMP: 복제 자리는 디자인 확인 전이라 임시로 정한 값
    fileprivate static let duplicateGap = 0.5
}

// 사람·발화지점
extension PlanData {
    /// 바닥 위 point(도면 좌표, m)에 사람·발화지점을 놓고 새 id를 돌려준다. 방 안이 아니면(벽 위·벽 바깥·도면 밖) 놓지 않고 nil.
    /// 사람은 늘 누운 자세로 놓는다.
    /// TEMP: 새 스탬프의 높이·방향은 디자인 확인 전이라 바닥(0m)·위쪽(0°)으로 둠
    mutating func addMarker(_ kind: MarkerKind, at point: SIMD2<Double>) -> String? {
        guard isInsideRoom(point) else { return nil }
        let marker = PlanMarker(
            id: UUID().uuidString,
            kind: kind,
            position: point,
            height: 0,
            yaw: 0,
            lying: kind == .person ? true : nil
        )
        markers.append(marker)
        return marker.id
    }

    /// 사람·발화지점을 바닥 위 point(도면 좌표, m)로 옮긴다. 방 안이 아니면 옮기지 않는다
    mutating func moveMarker(id: String, to point: SIMD2<Double>) {
        guard isInsideRoom(point), let index = markers.firstIndex(where: { $0.id == id }) else { return }
        markers[index].position = point
    }

    /// 사람·발화지점의 방향을 yaw(도)로 바꾼다. 0~360° 안으로 맞춘다
    mutating func rotateMarker(id: String, yaw: Double) {
        guard let index = markers.firstIndex(where: { $0.id == id }) else { return }
        let degrees = yaw.truncatingRemainder(dividingBy: 360)
        markers[index].yaw = degrees < 0 ? degrees + 360 : degrees
    }

    /// 사람·발화지점을 같은 종류·방향·자세로 옆에 하나 더 놓고 새 id를 돌려준다.
    /// 오른쪽부터 왼쪽·아래·위 순서로 방 안인 자리를 찾고, 없으면 복제하지 않고 nil
    mutating func duplicateMarker(id: String) -> String? {
        guard let original = markers.first(where: { $0.id == id }) else { return nil }
        let gap = Self.duplicateGap
        let offsets = [SIMD2(gap, 0), SIMD2(-gap, 0), SIMD2(0, gap), SIMD2(0, -gap)]
        guard let position = offsets.map({ original.position + $0 }).first(where: isInsideRoom) else { return nil }
        let copy = PlanMarker(
            id: UUID().uuidString,
            kind: original.kind,
            position: position,
            height: original.height,
            yaw: original.yaw,
            lying: original.lying,
            scale: original.scale
        )
        markers.append(copy)
        return copy.id
    }

    /// 사람·발화지점의 크기 배율을 바꾼다. markerScaleRange 안으로 맞춘다
    mutating func resizeMarker(id: String, scale: Double) {
        guard let index = markers.firstIndex(where: { $0.id == id }) else { return }
        markers[index].scale = min(max(scale, Self.markerScaleRange.lowerBound), Self.markerScaleRange.upperBound)
    }

    /// 사람·발화지점 크기 배율의 범위
    /// TEMP: 디자인 확인 전이라 임시로 정한 값 (기본의 절반 ~ 2.5배)
    static let markerScaleRange = 0.5...2.5

    mutating func removeMarker(id: String) {
        markers.removeAll { $0.id == id }
    }
}

// 콘센트처럼 벽에 붙는 것
extension PlanData {
    /// 벽 wallId의 면 위 점 point(도면 좌표)와 바닥에서 높이 height(m)에 콘센트 같은 것을 붙이고 새 id를 돌려준다.
    /// 누른 쪽 면이 방 안을 보지 않으면(벽 바깥) 반대쪽 면에 붙인다. 두 면 다 방 안이 아니거나 벽을 찾지 못하면 nil
    mutating func addWallFixture(_ kind: FixtureKind, wallId: String, at point: SIMD2<Double>, height: Double) -> String? {
        guard let spot = wallSpot(wallId: wallId, point: point, height: height) else { return nil }
        let otherFace: WallFace = spot.face == .left ? .right : .left
        guard let face = [spot.face, otherFace].first(where: { facesRoom(wallId: wallId, face: $0, along: spot.along) }) else { return nil }
        let fixture = WallFixture(
            id: UUID().uuidString,
            wallId: wallId,
            kind: kind,
            face: face,
            positionAlongWall: spot.along,
            heightFromFloor: spot.height
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
            heightFromFloor: original.heightFromFloor
        )
        wallFixtures.append(copy)
        return copy.id
    }

    mutating func removeWallFixture(id: String) {
        wallFixtures.removeAll { $0.id == id }
    }

    /// 벽 시작점에서 along(m) 자리의 face 쪽 면 바로 앞이 방 안인지
    private func facesRoom(wallId: String, face: WallFace, along: Double) -> Bool {
        guard let wall = wall(id: wallId), let line = line(of: wall) else { return false }
        let side = face == .left ? 1.0 : -1.0
        let inFront = line.point(along: along) + line.leftNormal * (side * (wall.thickness / 2 + Self.faceCheckGap))
        return isInsideRoom(inFront)
    }

    /// 벽 면 앞 몇 m를 방 안인지 볼지. 면 바로 위는 벽 두께와 겹쳐 조금 떨어진 곳을 본다
    private static let faceCheckGap = 0.05

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

// 창문
extension PlanData {
    /// 새 창문 크기 (m)
    /// TEMP: 디자인 확인 전이라 흔한 창문 크기로 임시로 정한 값
    fileprivate static let newWindowWidth = 1.0
    fileprivate static let newWindowHeight = 1.2
    fileprivate static let newWindowSillHeight = 0.9
    /// 창문 폭·높이의 가장 작은 값 (m)
    fileprivate static let minimumWindowSize = 0.2

    /// 벽 wallId 위 점 point(도면 좌표)를 가운데로 창문을 달고 새 id를 돌려준다.
    /// 벽 끝이나 옆 문·창문과 겹치면 그 사이 빈 칸 안으로 줄이거나 밀어 넣는다. 빈 칸이 너무 좁거나 벽을 찾지 못하면 nil
    mutating func addWindow(wallId: String, at point: SIMD2<Double>) -> String? {
        guard let wall = wall(id: wallId), let line = line(of: wall) else { return nil }
        let along = ((point - line.start) * line.direction).sum()
        let gap = openingGap(on: wall, line: line, around: along, excluding: nil)
        let width = min(Self.newWindowWidth, gap.upperBound - gap.lowerBound)
        let height = min(Self.newWindowHeight, wall.height - Self.newWindowSillHeight)
        guard width >= Self.minimumWindowSize, height >= Self.minimumWindowSize else { return nil }
        let window = DoorWindow(
            id: UUID().uuidString,
            wallId: wallId,
            kind: .window,
            centerAlongWall: min(max(along, gap.lowerBound + width / 2), gap.upperBound - width / 2),
            width: width,
            sillHeight: Self.newWindowSillHeight,
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

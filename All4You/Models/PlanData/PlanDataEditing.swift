// 도면의 스탬프를 더하고 옮기고 돌리고 복제·삭제하는 계산. 화면은 도면 좌표만 넘기고, 저장 모양(벽 기준 위치·면 등)은 여기서 정한다

import Foundation

extension PlanData {
    /// 복제한 스탬프를 원래 것에서 떨어뜨리는 거리 (m). 사람·발화지점은 도면 오른쪽으로, 벽에 붙은 것은 벽을 따라
    /// TEMP: 복제 자리는 디자인 확인 전이라 임시로 정한 값
    fileprivate static let duplicateGap = 0.5
}

// 사람·발화지점
extension PlanData {
    /// 바닥 위 point(도면 좌표, m)에 사람·발화지점을 놓고 새 id를 돌려준다.
    /// 사람은 늘 누운 자세로 놓는다.
    /// TEMP: 새 스탬프의 높이·방향은 디자인 확인 전이라 바닥(0m)·위쪽(0°)으로 둠
    mutating func addMarker(_ kind: MarkerKind, at point: SIMD2<Double>) -> String {
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

    /// 사람·발화지점을 바닥 위 point(도면 좌표, m)로 옮긴다
    mutating func moveMarker(id: String, to point: SIMD2<Double>) {
        guard let index = markers.firstIndex(where: { $0.id == id }) else { return }
        markers[index].position = point
    }

    /// 사람·발화지점의 방향을 yaw(도)로 바꾼다. 0~360° 안으로 맞춘다
    mutating func rotateMarker(id: String, yaw: Double) {
        guard let index = markers.firstIndex(where: { $0.id == id }) else { return }
        let degrees = yaw.truncatingRemainder(dividingBy: 360)
        markers[index].yaw = degrees < 0 ? degrees + 360 : degrees
    }

    /// 사람·발화지점을 같은 종류·방향·자세로 옆에 하나 더 놓고 새 id를 돌려준다
    mutating func duplicateMarker(id: String) -> String? {
        guard let original = markers.first(where: { $0.id == id }) else { return nil }
        let copy = PlanMarker(
            id: UUID().uuidString,
            kind: original.kind,
            position: original.position + SIMD2(Self.duplicateGap, 0),
            height: original.height,
            yaw: original.yaw,
            lying: original.lying
        )
        markers.append(copy)
        return copy.id
    }

    mutating func removeMarker(id: String) {
        markers.removeAll { $0.id == id }
    }
}

// 콘센트처럼 벽에 붙는 것
extension PlanData {
    /// 벽 wallId의 면 위 점 point(도면 좌표)와 바닥에서 높이 height(m)에 콘센트 같은 것을 붙이고 새 id를 돌려준다.
    /// 벽을 찾지 못하면 nil
    mutating func addWallFixture(_ kind: FixtureKind, wallId: String, at point: SIMD2<Double>, height: Double) -> String? {
        guard let spot = wallSpot(wallId: wallId, point: point, height: height) else { return nil }
        let fixture = WallFixture(
            id: UUID().uuidString,
            wallId: wallId,
            kind: kind,
            face: spot.face,
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

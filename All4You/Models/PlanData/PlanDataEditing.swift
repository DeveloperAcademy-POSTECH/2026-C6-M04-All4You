// 도면에 스탬프를 더하는 계산. 화면은 누른 자리(도면 좌표)만 넘기고, 저장 모양(벽 기준 위치·면 등)은 여기서 정한다

import Foundation

extension PlanData {
    /// 바닥 위 point(도면 좌표, m)에 사람·발화지점을 놓고 새 id를 돌려준다.
    /// TEMP: 새 스탬프의 높이·방향·자세는 디자인 확인 전이라 바닥(0m)·위쪽(0°)·선 자세로 둠
    mutating func addMarker(_ kind: MarkerKind, at point: SIMD2<Double>) -> String {
        let marker = PlanMarker(
            id: UUID().uuidString,
            kind: kind,
            position: point,
            height: 0,
            yaw: 0,
            lying: kind == .person ? false : nil
        )
        markers.append(marker)
        return marker.id
    }

    /// 벽 wallId의 면 위 점 point(도면 좌표)와 바닥에서 높이 height(m)에 콘센트 같은 것을 붙이고 새 id를 돌려준다.
    /// 벽을 따라간 위치는 벽 안으로, 높이는 벽 높이 안으로 맞춘다. 벽을 찾지 못하면 nil
    mutating func addWallFixture(_ kind: FixtureKind, wallId: String, at point: SIMD2<Double>, height: Double) -> String? {
        guard let wall = wall(id: wallId), let line = line(of: wall) else { return nil }
        let offset = point - line.start
        let along = (offset * line.direction).sum()
        let side = (offset * line.leftNormal).sum()
        let fixture = WallFixture(
            id: UUID().uuidString,
            wallId: wallId,
            kind: kind,
            face: side >= 0 ? .left : .right,
            positionAlongWall: min(max(along, 0), line.length),
            heightFromFloor: min(max(height, 0), wall.height)
        )
        wallFixtures.append(fixture)
        return fixture.id
    }
}

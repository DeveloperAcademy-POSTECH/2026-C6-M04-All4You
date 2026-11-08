// 2D 화면에서 누른 점이 도면의 무엇 위인지 찾는다. 스탬프 → 벽 → 바닥 순서로 본다

import CoreGraphics

extension PlanScreen {
    /// 화면 점 point를 누른 곳으로 바꾼다
    func tap(at point: CGPoint, in plan: PlanData) -> PlanTap {
        if let element = stamp(at: point, in: plan) {
            return .element(element)
        }
        let planPoint = self.plan(point)
        if let wallId = wall(at: planPoint, in: plan) {
            return .wall(id: wallId, point: planPoint, height: Plan2DHit.outletHeight)
        }
        return .floor(planPoint)
    }

    /// 아이콘 안을 누른 스탬프. 겹치면 나중에 그린(위에 보이는) 것
    func stamp(at point: CGPoint, in plan: PlanData) -> PlanSelection? {
        /// 크기 배율 scale인 스탬프가 planPoint에 있을 때 누른 점이 아이콘 안인지
        func isNear(_ planPoint: SIMD2<Double>, scale: Double = 1) -> Bool {
            let radius = length(Plan2DView.stampSize * scale) / 2 + Plan2DHit.fingerMargin
            let screenPoint = self.point(planPoint)
            return hypot(screenPoint.x - point.x, screenPoint.y - point.y) <= radius
        }
        if let fixture = plan.wallFixtures.last(where: { plan.point(of: $0).map { isNear($0) } ?? false }) {
            return .wallFixture(fixture.id)
        }
        if let marker = plan.markers.last(where: { isNear($0.position, scale: $0.drawScale) }) {
            return .marker(marker.id)
        }
        return nil
    }

    /// planPoint에서 가장 가까운 벽. 벽 두께 절반에 손가락 여유를 더한 거리 안에 없으면 nil. 가상 경계선은 고르지 않는다
    private func wall(at planPoint: SIMD2<Double>, in plan: PlanData) -> String? {
        let margin = Plan2DHit.fingerMargin / scale
        return plan.walls
            .filter { !$0.isVirtual }
            .compactMap { wall -> (id: String, distance: Double)? in
                guard let line = plan.line(of: wall) else { return nil }
                let distance = line.distance(to: planPoint)
                return distance <= wall.thickness / 2 + margin ? (wall.id, distance) : nil
            }
            .min { $0.distance < $1.distance }?
            .id
    }
}

extension PlanData {
    /// 콘센트처럼 벽에 붙은 것이 놓인 도면 점. 붙은 면 쪽 벽 표면 위다. 벽을 찾지 못하면 nil
    func point(of fixture: WallFixture) -> SIMD2<Double>? {
        guard let wall = wall(id: fixture.wallId), let line = line(of: wall) else { return nil }
        let side = fixture.face == .left ? 1.0 : -1.0
        return line.point(along: fixture.positionAlongWall) + line.leftNormal * (side * wall.thickness / 2)
    }
}

/// 2D 누르기 값
enum Plan2DHit {
    /// 손가락이 조금 빗나가도 맞게 더하는 여유 (pt)
    static let fingerMargin: CGFloat = 12
    /// 2D에서 벽에 붙이는 콘센트의 바닥에서 높이 (m). 위에서 본 그림이라 높이를 누를 수 없다
    // TEMP: 흔한 콘센트 높이로 임시로 정한 값 — 디자인이나 사용자 확인 뒤 바꿀 수 있음
    static let outletHeight = 0.3
}

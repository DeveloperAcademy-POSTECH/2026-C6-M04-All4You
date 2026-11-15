// 2D 화면에서 누른 점이 도면의 무엇 위인지 찾는다. 스탬프 → 벽 → 바닥 순서로 본다

import CoreGraphics

extension PlanScreen {
    /// 화면 점 point를 누른 곳으로 바꾼다. includesDoorSwing이 참이면 문이 열리는 부채꼴 안도 그 문을 누른 것으로 본다
    func tap(at point: CGPoint, in plan: PlanData, includesDoorSwing: Bool = true) -> PlanTap {
        if let element = stamp(at: point, in: plan) {
            return .element(element)
        }
        let planPoint = self.plan(point)
        if let wallId = wall(at: planPoint, in: plan) {
            if let opening = opening(on: wallId, at: planPoint, in: plan) {
                return .element(.doorWindow(opening))
            }
            return .wall(id: wallId, point: planPoint, height: Plan2DHit.outletHeight)
        }
        if includesDoorSwing, let door = doorSwing(at: planPoint, in: plan) {
            return .element(.doorWindow(door))
        }
        return .floor(planPoint)
    }

    /// 아이콘 안을 누른 스탬프. 겹치면 나중에 그린(위에 보이는) 것
    func stamp(at point: CGPoint, in plan: PlanData) -> PlanSelection? {
        /// 아이콘 크기 size(m)인 스탬프가 planPoint에 있을 때 누른 점이 아이콘 안인지
        func isNear(_ planPoint: SIMD2<Double>, size: Double? = nil) -> Bool {
            let size = size ?? outletSize
            let radius = length(size) / 2 + Plan2DHit.fingerMargin
            let screenPoint = self.point(planPoint)
            return hypot(screenPoint.x - point.x, screenPoint.y - point.y) <= radius
        }
        if let fixture = plan.wallFixtures.last(where: { plan.point(of: $0).map { isNear($0) } ?? false }) {
            return .wallFixture(fixture.id)
        }
        if let marker = plan.markers.last(where: { isNear($0.position, size: Plan2DView.iconSize(of: $0)) }) {
            return .marker(marker.id)
        }
        return nil
    }

    /// 공간 이름 캡슐 안을 누른 방 (Room.id). 겹치면 나중에 그린(위에 보이는) 것
    func roomLabel(at point: CGPoint, in plan: PlanData, labelScale: CGFloat = 1) -> String? {
        plan.rooms.last { room in
            let size = Plan2DHit.capsuleSize(of: room.name, font: Plan2DHit.roomLabelFont, scale: labelScale)
            return Plan2DHit.contains(point, capsuleAt: self.point(SIMD2(room.labelX, room.labelY)), size: size)
        }?.id
    }

    /// 가구 이름 캡슐 안을 누른 가구 (Furniture.id). 겹치면 나중에 그린 것
    func furnitureLabel(at point: CGPoint, in plan: PlanData, labelScale: CGFloat = 1) -> String? {
        plan.furniture?.last { furniture in
            let size = Plan2DHit.capsuleSize(of: furniture.label, font: Plan2DHit.furnitureLabelFont, scale: labelScale)
            return Plan2DHit.contains(point, capsuleAt: self.point(furniture.center), size: size)
        }?.id
    }

    /// 스탬프 아래 종류 라벨 캡슐의 가운데 (화면 점). 고른 테두리 바로 아래이고, 캡슐은 가운데 기준으로 키우고 줄므로 키운 높이의 절반만큼 더 내린다
    func kindLabelCenter(at planPoint: SIMD2<Double>, iconSize: Double, labelScale: CGFloat) -> CGPoint {
        let center = point(planPoint)
        let below = length(iconSize) / 2 + Plan2DView.selectionPadding + Plan2DView.kindLabelGap + StampKindLabelView.height * labelScale / 2
        return CGPoint(x: center.x, y: center.y + below)
    }

    /// 종류가 기타인 스탬프의 종류 라벨 캡슐 자리 (PlanMarker.id·WallFixture.id와 화면 점). 라벨 글자를 고칠 수 있는 스탬프만 돌려준다
    func otherKindLabels(in plan: PlanData, labelScale: CGFloat) -> [(id: String, center: CGPoint, text: String)] {
        let markers = plan.markers.filter(\.isKindOther).compactMap { marker in
            marker.kindLabel.map { (marker.id, kindLabelCenter(at: marker.position, iconSize: Plan2DView.iconSize(of: marker), labelScale: labelScale), $0) }
        }
        let fixtures = plan.wallFixtures.filter(\.isKindOther).compactMap { fixture -> (id: String, center: CGPoint, text: String)? in
            guard let text = fixture.kindLabel, let point = plan.point(of: fixture) else { return nil }
            return (fixture.id, kindLabelCenter(at: point, iconSize: outletSize, labelScale: labelScale), text)
        }
        return fixtures + markers
    }

    /// 종류가 기타인 스탬프의 종류 라벨 캡슐 안을 누른 스탬프 (PlanMarker.id·WallFixture.id). 겹치면 나중에 그린 것
    func otherKindLabel(at point: CGPoint, in plan: PlanData, labelScale: CGFloat = 1) -> String? {
        otherKindLabels(in: plan, labelScale: labelScale).last { label in
            let size = Plan2DHit.capsuleSize(of: label.text, font: Plan2DHit.stampKindLabelFont, scale: labelScale)
            return Plan2DHit.contains(point, capsuleAt: label.center, size: size)
        }?.id
    }

    /// 벽 wallId에서 planPoint 자리에 달린 창문·문 (DoorWindow.id). 문짝 없는 개구부는 고르지 않는다
    private func opening(on wallId: String, at planPoint: SIMD2<Double>, in plan: PlanData) -> String? {
        guard let wall = plan.wall(id: wallId), let line = plan.line(of: wall) else { return nil }
        let along = ((planPoint - line.start) * line.direction).sum()
        return plan.doorWindows.first { opening in
            opening.wallId == wallId && opening.kind != .passage
                && abs(along - opening.centerAlongWall) <= opening.width / 2
        }?.id
    }

    /// planPoint가 문이 열리는 부채꼴 안인 문 (DoorWindow.id). 부채꼴은 문 시작 쪽 끝을 경첩으로, 문 폭을 반지름으로 벽 왼쪽에 그려지는 사분원이다. 판정에는 손가락 여유를 더한다
    private func doorSwing(at planPoint: SIMD2<Double>, in plan: PlanData) -> String? {
        let margin = Plan2DHit.fingerMargin / scale
        return plan.doorWindows.first { opening in
            guard opening.kind == .door, let wall = plan.wall(id: opening.wallId), let line = plan.line(of: wall) else { return false }
            let hinge = line.point(along: opening.centerAlongWall - opening.width / 2)
            let offset = planPoint - hinge
            let along = (offset * line.direction).sum()
            let across = (offset * line.leftNormal).sum()
            return along >= -margin && across >= -margin && (offset * offset).sum().squareRoot() <= opening.width + margin
        }?.id
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

    /// 이름 캡슐 글자 크기와 안쪽 여백 (pt). RoomLabelView·FurnitureLabelView와 같은 값이다
    static let roomLabelFont = CapsuleFont(size: 15, horizontalPadding: 16, verticalPadding: 8)
    static let furnitureLabelFont = CapsuleFont(size: 12, horizontalPadding: 13, verticalPadding: 7.5)
    /// 스탬프 종류 라벨 (StampKindLabelView)
    static let stampKindLabelFont = CapsuleFont(
        size: StampKindLabelView.Layout.fontSize,
        horizontalPadding: StampKindLabelView.Layout.horizontalPadding,
        verticalPadding: StampKindLabelView.Layout.verticalPadding
    )

    struct CapsuleFont {
        let size: CGFloat
        let horizontalPadding: CGFloat
        let verticalPadding: CGFloat
    }

    /// 이름을 담은 캡슐의 대략적인 크기 (pt). 뷰가 그려진 크기를 알 수 없어, 한글은 글자 크기만큼 라틴 글자는 0.55배로 어림한다.
    /// 지우개와 가구 이름 누르기가 캡슐을 맞히는 데 쓰므로 손가락 여유(fingerMargin의 절반)를 더해 조금 넉넉하게 둔다
    /// scale은 도면을 확대·축소하며 캡슐을 키우고 줄이는 배율 (LabelScale). 캡슐 크기에만 곱하고 손가락 여유는 그대로 둔다
    static func capsuleSize(of text: String, font: CapsuleFont, scale: CGFloat = 1) -> CGSize {
        let textWidth = text.reduce(CGFloat(0)) { $0 + ($1.isASCII ? font.size * 0.55 : font.size) }
        let margin = fingerMargin / 2
        return CGSize(
            width: (textWidth + font.horizontalPadding * 2) * scale + margin * 2,
            height: (font.size * 1.2 + font.verticalPadding * 2) * scale + margin * 2
        )
    }

    /// 화면 점이 center를 가운데로 한 size 크기의 캡슐 안인지
    static func contains(_ point: CGPoint, capsuleAt center: CGPoint, size: CGSize) -> Bool {
        abs(point.x - center.x) <= size.width / 2 && abs(point.y - center.y) <= size.height / 2
    }
}

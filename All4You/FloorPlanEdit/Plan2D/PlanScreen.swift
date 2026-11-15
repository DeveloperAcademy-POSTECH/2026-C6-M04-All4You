// 2D 화면에서 도면 좌표(m) ↔ 화면 좌표(pt) 변환. 화면 맞춤과 확대·이동·회전을 값 하나로 담는다

import CoreGraphics
import Foundation

/// 도면이 화면 어디에 어떤 배율로 놓였는지. 확대·이동하면 새 값을 만들어 화면의 @State에 넣는다
struct PlanScreen: Equatable {
    /// 꼭짓점을 모두 감싸는 사각형의 왼쪽 위 (도면 좌표, m)
    let minPoint: SIMD2<Double>
    /// 꼭짓점을 모두 감싸는 가로·세로 (m)
    let planSize: SIMD2<Double>
    /// 화면에 처음 맞췄을 때의 배율. 확대·축소 한계의 기준
    let fitScale: Double
    /// 1m가 화면에서 몇 pt인지
    private(set) var scale: Double
    /// 도면을 시계 방향으로 돌린 각 (라디안). minPoint(도면 왼쪽 위)를 축으로 돈다. 저장된 값은 PlanData.planRotation
    private(set) var rotation: Double
    /// minPoint가 놓이는 화면 점
    private(set) var origin: CGPoint

    /// 도면을 비율 그대로 화면 가운데에 놓는다. fill은 가로·세로 중 꽉 차는 쪽에서 도면이 차지하는 몫.
    /// 도면에 저장된 회전각(planRotation)으로 돌린 모양이 화면에 맞는다
    init(plan: PlanData, in size: CGSize, fill: Double = 1) {
        let bounds = plan.bounds
        minPoint = bounds.min
        // 꼭짓점이 없거나 한 줄로만 있어도 0으로 나누지 않게 아주 작은 크기를 둔다
        planSize = SIMD2(max(bounds.max.x - bounds.min.x, 0.1), max(bounds.max.y - bounds.min.y, 0.1))
        let angle = plan.planRotation ?? 0
        // 돌린 도면을 감싸는 가로·세로 (m). 돌리지 않았으면 도면 크기 그대로다
        let cosine = abs(cos(angle))
        let sine = abs(sin(angle))
        let boundsWidth = planSize.x * cosine + planSize.y * sine
        let boundsHeight = planSize.x * sine + planSize.y * cosine
        fitScale = min(size.width / boundsWidth, size.height / boundsHeight) * fill
        scale = fitScale
        rotation = angle
        // 도면 가운데가 화면 가운데에 오도록, 왼쪽 위 점을 가운데에서 돌린 만큼 되짚어 정한다
        let halfExtent = CGPoint(x: planSize.x * fitScale / 2, y: planSize.y * fitScale / 2)
        let turnedHalf = Self.turned(halfExtent, by: angle)
        origin = CGPoint(x: size.width / 2 - turnedHalf.x, y: size.height / 2 - turnedHalf.y)
    }

    /// 도면이 그려지는 화면 사각형. 돌렸으면 돌린 도면을 감싸는 사각형이다
    var rect: CGRect {
        let corners = [
            SIMD2(minPoint.x, minPoint.y), SIMD2(minPoint.x + planSize.x, minPoint.y),
            SIMD2(minPoint.x, minPoint.y + planSize.y), SIMD2(minPoint.x + planSize.x, minPoint.y + planSize.y)
        ].map(point)
        let xs = corners.map(\.x)
        let ys = corners.map(\.y)
        return CGRect(x: xs.min() ?? 0, y: ys.min() ?? 0, width: (xs.max() ?? 0) - (xs.min() ?? 0), height: (ys.max() ?? 0) - (ys.min() ?? 0))
    }

    /// 도면 점 (m)을 화면 점으로. 배율을 곱하고 rotation만큼 돌린 뒤 origin에 더한다
    func point(_ p: SIMD2<Double>) -> CGPoint {
        let turned = Self.turned(CGPoint(x: (p.x - minPoint.x) * scale, y: (p.y - minPoint.y) * scale), by: rotation)
        return CGPoint(x: origin.x + turned.x, y: origin.y + turned.y)
    }

    /// 화면 점을 도면 점 (m)으로 (point의 반대)
    func plan(_ point: CGPoint) -> SIMD2<Double> {
        let back = Self.turned(CGPoint(x: point.x - origin.x, y: point.y - origin.y), by: -rotation)
        return SIMD2(back.x / scale + minPoint.x, back.y / scale + minPoint.y)
    }

    /// 화면 점 p를 원점 기준으로 angle(라디안, 시계 방향)만큼 돌린 점. 화면은 아래가 +y라 양수가 시계 방향이다
    private static func turned(_ p: CGPoint, by angle: Double) -> CGPoint {
        CGPoint(x: p.x * cos(angle) - p.y * sin(angle), y: p.x * sin(angle) + p.y * cos(angle))
    }

    /// 도면을 돌린 각 (도). 스탬프처럼 도면 방향으로 놓이는 아이콘의 화면 방향에 더한다
    var rotationDegrees: Double {
        rotation * 180 / .pi
    }

    /// 콘센트 아이콘 크기 (m). 처음 맞춘 화면에서 스탬프 기본 크기(StampDefaults.iconPoints)로 보이는 크기라, 확대하면 도면과 함께 커진다
    var outletSize: Double {
        StampDefaults.iconPoints / fitScale
    }

    /// 처음 맞춘 크기의 몇 배로 보이는지 (처음 = 1)
    var zoom: Double {
        scale / fitScale
    }

    /// 확대·축소에 맞춰 이름 캡슐 크기에 곱하는 배율 (LabelScale). 처음 맞춘 화면에서 1
    var labelScale: CGFloat {
        LabelScale.value(zoom: zoom, zoomRange: Limit.minZoom...Limit.maxZoom)
    }

    /// 도면 길이 (m)를 화면 길이 (pt)로
    func length(_ meters: Double) -> CGFloat {
        meters * scale
    }

    /// anchor(손가락 사이 화면 점)가 제자리에 있도록 factor배 확대·축소한 값. 맞춤 배율의 0.5~5배로 제한한다
    func zoomed(by factor: Double, around anchor: CGPoint) -> PlanScreen {
        var next = self
        next.scale = min(max(scale * factor, fitScale * Limit.minZoom), fitScale * Limit.maxZoom)
        let ratio = next.scale / scale
        next.origin = CGPoint(x: anchor.x - (anchor.x - origin.x) * ratio, y: anchor.y - (anchor.y - origin.y) * ratio)
        return next
    }

    /// 화면에서 offset만큼 끌어 옮긴 값
    func moved(by offset: CGSize) -> PlanScreen {
        var next = self
        next.origin = CGPoint(x: origin.x + offset.width, y: origin.y + offset.height)
        return next
    }

    /// anchor(손가락 사이 화면 점)가 제자리에 있도록 delta(라디안, 시계 방향)만큼 더 돌린 값
    func rotated(by delta: Double, around anchor: CGPoint) -> PlanScreen {
        // 유한하지 않은 값이 들어오면 도면 자리가 NaN이 되어 화면에서 사라지므로, 돌리지 않고 그대로 둔다
        guard delta.isFinite, anchor.x.isFinite, anchor.y.isFinite else { return self }
        var next = self
        next.rotation = rotation + delta
        let turned = Self.turned(CGPoint(x: origin.x - anchor.x, y: origin.y - anchor.y), by: delta)
        next.origin = CGPoint(x: anchor.x + turned.x, y: anchor.y + turned.y)
        return next
    }

    /// 돌린 각을 angle로 맞춘 값. 되돌리기·다시 하기로 저장된 각이 바뀌었을 때 화면을 거기에 맞춘다
    func rotated(to angle: Double, around anchor: CGPoint) -> PlanScreen {
        rotated(by: angle - rotation, around: anchor)
    }
}

// 돌린 각 정리
extension PlanScreen {
    /// 도면에 저장할 회전각. -180°~180° 안으로 줄이고, 가로·세로 방향(90° 단위)에 몇 도 안으로 가까우면 그 방향으로 맞춘다. 돌리지 않은 것과 같으면 nil
    var savedRotation: Double? {
        let wrapped = atan2(sin(rotation), cos(rotation))
        let quarter = Double.pi / 2
        let nearest = (wrapped / quarter).rounded() * quarter
        let settled = abs(wrapped - nearest) <= Limit.snapRadians ? nearest : wrapped
        return abs(settled) < Limit.zeroRadians ? nil : settled
    }

    /// 돌린 각을 savedRotation으로 정리한 값. 손을 뗐을 때 90° 방향에 붙인다
    func settled(around anchor: CGPoint) -> PlanScreen {
        rotated(to: savedRotation ?? 0, around: anchor)
    }
}

// 확대 한계
extension PlanScreen {
    private enum Limit {
        static let minZoom = 0.5
        static let maxZoom = 5.0
        /// 돌린 도면을 90° 방향에 붙이는 범위 (라디안, 약 4°)
        static let snapRadians = Double.pi / 45
        /// 이보다 작은 각은 돌리지 않은 것으로 본다
        static let zeroRadians = 1e-6
    }
}

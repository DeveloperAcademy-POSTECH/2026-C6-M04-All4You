// 2D 화면에서 도면 좌표(m) ↔ 화면 좌표(pt) 변환. 화면 맞춤과 확대·이동을 값 하나로 담는다

import CoreGraphics

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
    /// minPoint가 놓이는 화면 점
    private(set) var origin: CGPoint

    /// 도면을 비율 그대로 화면 가운데에 놓는다. fill은 가로·세로 중 꽉 차는 쪽에서 도면이 차지하는 몫
    init(plan: PlanData, in size: CGSize, fill: Double = 1) {
        let bounds = plan.bounds
        minPoint = bounds.min
        // 꼭짓점이 없거나 한 줄로만 있어도 0으로 나누지 않게 아주 작은 크기를 둔다
        planSize = SIMD2(max(bounds.max.x - bounds.min.x, 0.1), max(bounds.max.y - bounds.min.y, 0.1))
        fitScale = min(size.width / planSize.x, size.height / planSize.y) * fill
        scale = fitScale
        origin = CGPoint(
            x: (size.width - planSize.x * fitScale) / 2,
            y: (size.height - planSize.y * fitScale) / 2
        )
    }

    /// 도면이 그려지는 화면 사각형
    var rect: CGRect {
        CGRect(origin: origin, size: CGSize(width: planSize.x * scale, height: planSize.y * scale))
    }

    /// 도면 점 (m)을 화면 점으로
    func point(_ p: SIMD2<Double>) -> CGPoint {
        CGPoint(x: origin.x + (p.x - minPoint.x) * scale, y: origin.y + (p.y - minPoint.y) * scale)
    }

    /// 화면 점을 도면 점 (m)으로 (point의 반대)
    func plan(_ point: CGPoint) -> SIMD2<Double> {
        SIMD2((point.x - origin.x) / scale + minPoint.x, (point.y - origin.y) / scale + minPoint.y)
    }

    /// 콘센트 아이콘 크기 (m). 처음 맞춘 화면에서 스탬프 기본 크기(StampDefaults.iconPoints)로 보이는 크기라, 확대하면 도면과 함께 커진다
    var outletSize: Double {
        StampDefaults.iconPoints / fitScale
    }

    /// 처음 맞춘 크기의 몇 배로 보이는지 (처음 = 1)
    var zoom: Double {
        scale / fitScale
    }

    /// 확대·축소에 맞춰 이름 캡슐을 키우고 줄이는 배율 (LabelScale 범위 안)
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
}

// 확대 한계
extension PlanScreen {
    private enum Limit {
        static let minZoom = 0.5
        static let maxZoom = 5.0
    }
}

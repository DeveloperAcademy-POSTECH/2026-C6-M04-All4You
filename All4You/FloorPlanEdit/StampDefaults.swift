// 스탬프를 놓을 때의 기본 크기. Figma "스탬프 크기"(61:29608)는 화면 pt로 정해져 있어서,
// 수정 화면을 처음 맞췄을 때의 배율(1m가 몇 pt인지)로 도면 길이(m)로 바꿔 쓴다

import CoreGraphics

/// 도구별 기본 크기를 도면 길이로 바꿔 주는 값. 수정 화면이 열릴 때 한 번 정하고, 도면이 커져도 바꾸지 않는다
struct StampDefaults: Equatable {
    /// 1m가 화면에서 몇 pt인지
    let pointsPerMeter: Double

    /// 발화지점·전기·피해자의 기본 크기 (pt)
    static let iconPoints = 40.0
    /// 문의 기본 크기 (pt). Figma 61:29608의 48×48 칸 안 아이콘 32pt
    static let doorPoints = 32.0
    /// 창문의 기본 폭 (pt). Figma 100×24
    static let windowWidthPoints = 100.0

    /// 화면 크기를 모르는 곳(3D 장면 등)에서 도면만으로 정하는 기준. iPad 도면 영역(위·아래 막대를 뺀 약 1000×640pt)을 가정하고 2D 수정 화면이 처음 맞추는 식과 같다
    static func reference(for plan: PlanData) -> StampDefaults {
        let fit = PlanScreen(plan: plan, in: CGSize(width: 1000, height: 640), fill: 0.85)
        return StampDefaults(pointsPerMeter: fit.fitScale)
    }

    /// 발화지점·전기·피해자 기본 크기를 도면 길이(m)로 바꾼 값
    var iconMeters: Double {
        Self.iconPoints / pointsPerMeter
    }

    /// 사람·발화지점 크기 배율. 아이콘이 iconPoints 크기로 보이게 하되 markerScaleRange 안으로 맞춘다
    func markerScale(_ kind: MarkerKind) -> Double {
        let base = PlanMarker(id: "", kind: kind, position: .zero, height: 0, yaw: 0, lying: kind == .person ? true : nil)
        let ratio = (Self.iconPoints / pointsPerMeter) / Plan2DView.iconSize(of: base)
        return min(max(ratio, PlanData.markerScaleRange.lowerBound), PlanData.markerScaleRange.upperBound)
    }

    /// 새 문의 폭 (m). 도면이 아주 작거나 커도 문답게 보이게 범위 안으로 맞춘다
    var doorWidth: Double {
        min(max(Self.doorPoints / pointsPerMeter, Self.doorRange.lowerBound), Self.doorRange.upperBound)
    }

    /// 새 창문의 폭 (m)
    var windowWidth: Double {
        min(max(Self.windowWidthPoints / pointsPerMeter, Self.windowRange.lowerBound), Self.windowRange.upperBound)
    }

    // TEMP: 도면 크기에 따라 지나치게 작거나 커지지 않게 한 임시 범위
    private static let doorRange = 0.6...1.2
    private static let windowRange = 0.6...2.4
}

// 도면을 확대·축소할 때 이름 캡슐(공간·가구 라벨)과 치수 글자를 얼마나 함께 키우고 줄일지 정하는 공용 값.
// 2D·3D 수정 화면이 쓰고, 메인 도면 탭과 Export 화면도 같은 값을 쓰도록 만들어 두었다

import CoreGraphics
import Foundation

enum LabelScale {
    /// 캡슐 배율의 최솟값·최댓값. 도면을 가장 줄였을 때와 가장 키웠을 때의 배율이다
    // TEMP: 실기기에서 줄이고 키워 보고 정함
    static let range: ClosedRange<CGFloat> = 0.6...0.8

    /// minimum은 가장 줄였을 때의 배율. 화면마다 따로 정할 수 있다.
    /// 도면이 처음 맞춘 크기의 몇 배로 보이는지(zoom, 처음 = 1)에 맞춰 캡슐 배율을 정한다.
    /// 확대·축소 한계(zoomRange) 전체에 걸쳐 배율이 끊김 없이 이어지고, 도면이 더 커지거나 작아질 수 없는 한계에서 함께 멈춘다
    /// (한계보다 먼저 멈추면 도면은 계속 커지는데 캡슐만 멈춘 것처럼 보인다). 곱셈으로 느껴지는 확대·축소 느낌에 맞게 로그 눈금으로 잇는다
    static func value(zoom: Double, zoomRange: ClosedRange<Double>, minimum: CGFloat = range.lowerBound) -> CGFloat {
        let clamped = min(max(zoom, zoomRange.lowerBound), zoomRange.upperBound)
        if clamped >= 1 {
            guard zoomRange.upperBound > 1 else { return 1 }
            let progress = log(clamped) / log(zoomRange.upperBound)
            return 1 + (range.upperBound - 1) * CGFloat(progress)
        }
        guard zoomRange.lowerBound < 1 else { return 1 }
        let progress = log(clamped) / log(zoomRange.lowerBound)
        return 1 - (1 - minimum) * CGFloat(progress)
    }
}

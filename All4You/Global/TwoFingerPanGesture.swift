// 두 손가락으로 끄는 제스처. SwiftUI에는 두 손가락 끌기가 없어서 UIKit의 끌기 인식기를 붙여 쓴다
// 오므리기(확대)와 함께 인식되므로, 확대하면서 옮길 수도 있다

import SwiftUI
import UIKit

/// 두 손가락이 움직일 때마다 두 손가락 가운데의 지금 점과 직전 점을 알려 준다 (붙인 뷰 기준 좌표)
struct TwoFingerPanGesture: UIGestureRecognizerRepresentable {
    let onChanged: (_ location: CGPoint, _ previous: CGPoint) -> Void
    /// 두 손가락을 뗐을 때
    var onEnded: () -> Void = {}

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let recognizer = UIPanGestureRecognizer()
        recognizer.minimumNumberOfTouches = 2
        recognizer.maximumNumberOfTouches = 2
        recognizer.delegate = context.coordinator
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let location = context.converter.localLocation
        switch recognizer.state {
        case .began:
            context.coordinator.lastLocation = location
        case .changed:
            // 한 손가락이 먼저 떨어지면 가운데 점이 남은 손가락 자리로 뛰므로, 두 손가락이 아닐 때는 옮기지 않고 기준점을 버린다
            guard recognizer.numberOfTouches == 2 else {
                context.coordinator.lastLocation = nil
                return
            }
            if let last = context.coordinator.lastLocation {
                onChanged(location, last)
            }
            context.coordinator.lastLocation = location
        case .ended, .cancelled, .failed:
            context.coordinator.lastLocation = nil
            onEnded()
        default:
            context.coordinator.lastLocation = nil
        }
    }

    /// 직전 점을 기억하고, 다른 제스처(오므리기 등)와 함께 인식되게 한다
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var lastLocation: CGPoint?

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}

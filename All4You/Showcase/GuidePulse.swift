// 쇼케이스용: 다음에 누를 버튼 둘레로 테두리가 퍼져 나가며 사라지는 파동

import SwiftUI

extension View {
    /// 켜져 있으면 버튼 둘레에 파동을 반복한다. 꺼지면 파동 뷰를 빼서 애니메이션이 멈춘다
    func guidePulse<S: Shape>(isActive: Bool, in shape: S, color: Color) -> some View {
        overlay {
            if isActive {
                GuidePulseRing(shape: shape, color: color)
            }
        }
    }
}

/// 도형 테두리 하나를 키우며 흐리게 하는 파동. 손 모션 줄이기가 켜져 있으면 움직이지 않는 테두리만 보인다
private struct GuidePulseRing<S: Shape>: View {
    let shape: S
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                shape.stroke(color, lineWidth: Layout.lineWidth)
            } else {
                shape.stroke(color, lineWidth: Layout.lineWidth)
                    .phaseAnimator([false, true]) { ring, isOut in
                        ring
                            .scaleEffect(isOut ? Layout.endScale : 1)
                            .opacity(isOut ? 0 : Layout.startOpacity)
                    } animation: { isOut in
                        // 퍼질 때만 움직이고, 처음 자리로는 바로 돌아간다
                        isOut ? .easeOut(duration: Layout.duration) : nil
                    }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// 제네릭 뷰 안에는 static 상수를 둘 수 없어 파일 수준으로 둔다
private enum Layout {
    static let lineWidth: CGFloat = 3
    static let endScale: CGFloat = 1.45
    static let startOpacity = 0.9
    /// 한 번 퍼지는 시간 (초)
    static let duration = 1.3
}

#Preview {
    HStack(spacing: 48) {
        Circle()
            .fill(.red)
            .frame(width: 72, height: 72)
            .guidePulse(isActive: true, in: Circle(), color: .red)

        Capsule()
            .fill(.brand500)
            .frame(width: 120, height: 44)
            .guidePulse(isActive: true, in: Capsule(), color: .brand500)
    }
    .padding(80)
}

// 고른 스탬프 위에 띄우는 회전 손잡이. 좌우로 끌면 스탬프가 돈다

import SwiftUI

/// 유리 원 안의 주황 회전 화살표
struct RotateHandleView: View {
    var body: some View {
        Image(systemName: "arrow.clockwise")
            .font(AppTypography.title3)
            .foregroundStyle(.brand500)
            .frame(width: Layout.size, height: Layout.size)
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel(Copy.label)
    }
}

// 레이아웃 값
extension RotateHandleView {
    private enum Layout {
        static let size: CGFloat = 44
    }
}

// 문구
extension RotateHandleView {
    private enum Copy {
        static let label = "회전"
    }
}

#Preview {
    RotateHandleView()
}

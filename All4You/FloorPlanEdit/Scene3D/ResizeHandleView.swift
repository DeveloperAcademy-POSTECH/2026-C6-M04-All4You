// 3D에서 고른 스탬프 옆에 띄우는 크기 손잡이. 가운데에서 멀어지게 끌면 커지고, 가까워지게 끌면 작아진다

import SwiftUI

/// 유리 원 안의 주황 양쪽 화살표
struct ResizeHandleView: View {
    var body: some View {
        Image(systemName: "arrow.up.left.and.arrow.down.right")
            .font(AppTypography.title3)
            .foregroundStyle(.brand500)
            .frame(width: Layout.size, height: Layout.size)
            // 누르면 커지는 유리 효과(.interactive())는 끄는 동안 손잡이가 커져 보여서 쓰지 않는다
            .glassEffect(.regular, in: .circle)
            .accessibilityLabel(Copy.label)
    }
}

// 레이아웃 값
extension ResizeHandleView {
    private enum Layout {
        static let size: CGFloat = 44
    }
}

// 문구
extension ResizeHandleView {
    private enum Copy {
        static let label = "크기"
    }
}

#Preview {
    ResizeHandleView()
}

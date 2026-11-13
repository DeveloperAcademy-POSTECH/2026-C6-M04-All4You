// 3D에서 고른 가구 옆에 띄우는 높이 손잡이. 위로 끌면 가구가 바닥에서 떠오르고, 아래로 끌면 내려온다

import SwiftUI

/// 유리 원 안의 주황 위아래 화살표
struct ElevationHandleView: View {
    var body: some View {
        Image(systemName: "arrow.up.and.down")
            .font(AppTypography.title3)
            .foregroundStyle(.brand500)
            .frame(width: Layout.size, height: Layout.size)
            .glassEffect(.regular, in: .circle)
            .accessibilityLabel(Copy.label)
    }
}

// 레이아웃 값
extension ElevationHandleView {
    private enum Layout {
        static let size: CGFloat = 44
    }
}

// 문구
extension ElevationHandleView {
    private enum Copy {
        static let label = "높이"
    }
}

#Preview {
    ElevationHandleView()
}

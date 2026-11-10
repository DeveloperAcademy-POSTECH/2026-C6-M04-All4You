// 도면을 확대하거나 옮긴 뒤 처음 시야로 되돌리는 유리 원 버튼. 2D·3D 수정 화면이 함께 쓴다

import SwiftUI

/// 누르면 처음 시야(배율·자리·3D는 카메라 방향까지)로 되돌린다
struct ResetViewButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "scope")
                .font(.system(size: Layout.iconSize, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: Layout.size, height: Layout.size)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(Copy.label)
    }
}

// 레이아웃 값
extension ResetViewButton {
    private enum Layout {
        static let size: CGFloat = 44
        static let iconSize: CGFloat = 17
    }
}

// 문구
extension ResetViewButton {
    private enum Copy {
        // TEMP: Figma에 없는 버튼이라 아이콘·문구를 임의로 정함 — 디자인 확인 필요
        static let label = "처음 시야로"
    }
}

#Preview {
    ResetViewButton {}
}

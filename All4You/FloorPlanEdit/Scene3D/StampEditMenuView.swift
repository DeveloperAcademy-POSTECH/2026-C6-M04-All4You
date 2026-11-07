// 스탬프를 꾹 누르면 옆에 띄우는 편집 메뉴. 복제·삭제 버튼을 유리 캡슐에 담는다

import SwiftUI

/// 복제 | 삭제 캡슐
struct StampEditMenuView: View {
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            menuButton(Copy.duplicate, systemImage: "plus.square.on.square", action: onDuplicate)
            divider
            menuButton(Copy.delete, systemImage: "trash", action: onDelete)
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .glassEffect(.regular, in: .capsule)
    }
}

// 서브 뷰
extension StampEditMenuView {
    private func menuButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .font(AppTypography.title3)
                .foregroundStyle(.primary)
                .frame(width: Layout.buttonWidth, height: Layout.height)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private var divider: some View {
        Divider()
            .frame(height: Layout.dividerHeight)
    }
}

// 레이아웃 값
extension StampEditMenuView {
    private enum Layout {
        static let height: CGFloat = 52
        static let buttonWidth: CGFloat = 56
        static let dividerHeight: CGFloat = 24
        static let horizontalPadding: CGFloat = 8
    }
}

// 문구
extension StampEditMenuView {
    private enum Copy {
        static let duplicate = "복제"
        static let delete = "삭제"
    }
}

#Preview {
    StampEditMenuView(onDuplicate: {}, onDelete: {})
}

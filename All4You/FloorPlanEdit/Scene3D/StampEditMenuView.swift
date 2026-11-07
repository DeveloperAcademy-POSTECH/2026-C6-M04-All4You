// 고른 스탬프 옆에 띄우는 편집 메뉴. 복제·삭제·더보기 버튼을 유리 캡슐에 담는다

import SwiftUI

/// 복제 | 삭제 | 더보기 캡슐
struct StampEditMenuView: View {
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            menuButton(Copy.duplicate, systemImage: "plus.square.on.square", action: onDuplicate)
            divider
            menuButton(Copy.delete, systemImage: "trash", action: onDelete)
            divider
            // TODO: 더보기에 넣을 메뉴는 아직 정해지지 않음
            menuButton(Copy.more, systemImage: "ellipsis") {}
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
        static let more = "더보기"
    }
}

#Preview {
    StampEditMenuView(onDuplicate: {}, onDelete: {})
}

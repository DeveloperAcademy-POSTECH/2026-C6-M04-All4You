// 도면 위에 띄우는 공간 이름 알약 (Figma 43:21764의 검은 알약)

import SwiftUI

/// 검은 알약 안의 흰 공간 이름
struct RoomLabelView: View {
    /// Room.name
    let name: String

    var body: some View {
        Text(name)
            .font(AppTypography.subheadline)
            .foregroundStyle(.white)
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.vertical, Layout.verticalPadding)
            .background(.black, in: .capsule)
    }
}

// 레이아웃 값
extension RoomLabelView {
    private enum Layout {
        static let horizontalPadding: CGFloat = 14
        static let verticalPadding: CGFloat = 6
    }
}

#Preview {
    RoomLabelView(name: "거실·주방")
}

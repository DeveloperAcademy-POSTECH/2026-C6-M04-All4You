// 도면 위에 띄우는 공간 라벨 캡슐

import SwiftUI

/// 검은 캡슐 안의 흰 텍스트(공간 라벨)
struct RoomLabelView: View {
    /// Room.name
    let name: String
    /// 도면 확대·축소에 맞춰 키우고 줄이는 배율 (LabelScale). 1이면 Figma 크기
    var scale: CGFloat = 1

    var body: some View {
        Text(name)
            .font(AppTypography.subheadline)
            .foregroundStyle(.white)
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.vertical, Layout.verticalPadding)
            .background(.black, in: .capsule)
            .scaleEffect(scale)
    }
}

// 레이아웃 값
extension RoomLabelView {
    private enum Layout {
        static let horizontalPadding: CGFloat = 16
        static let verticalPadding: CGFloat = 8
    }
}

#Preview {
    RoomLabelView(name: "거실·주방")
}

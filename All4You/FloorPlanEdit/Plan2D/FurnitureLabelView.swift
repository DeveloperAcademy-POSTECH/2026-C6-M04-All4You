// 2D 도면에서 가구 가운데에 띄우는 이름 캡슐. 공간 이름 캡슐보다 작고 흰 바탕에 검은 테두리다

import SwiftUI

/// 가구 이름 캡슐. 글자는 확대해도 같은 크기다
struct FurnitureLabelView: View {
    /// Furniture.label
    let label: String

    var body: some View {
        Text(label)
            .font(AppTypography.label)
            .foregroundStyle(.black)
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.vertical, Layout.verticalPadding)
            .background(.white, in: .capsule)
            .overlay {
                Capsule()
                    .stroke(.black, lineWidth: Layout.borderWidth)
            }
    }
}

// 레이아웃 값
extension FurnitureLabelView {
    private enum Layout {
        // Figma 61:29619 가구라벨 67×28
        static let horizontalPadding: CGFloat = 13
        static let verticalPadding: CGFloat = 7.5
        static let borderWidth: CGFloat = 1
    }
}

#Preview {
    FurnitureLabelView(label: "소파")
}

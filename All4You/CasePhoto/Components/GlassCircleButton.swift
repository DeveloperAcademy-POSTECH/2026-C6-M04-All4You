//
//  GlassCircleButton.swift
//  All4You
//
//  Created by SIA on 11/9/26.
//

// 사진 화면들(촬영·보기·마크업)의 위쪽에 놓는 유리 원 버튼

import SwiftUI

/// 아이콘 하나가 든 44pt 유리 원 버튼. isProminent면 주황으로 채운다
struct GlassCircleButton: View {
    let title: String
    let systemImage: String
    var isProminent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(AppTypography.headlineEmphasized)
                .foregroundStyle(.white)
                .frame(width: Layout.size, height: Layout.size)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(isProminent ? .regular.tint(.brand500).interactive() : .regular.interactive(), in: .circle)
        .accessibilityLabel(title)
    }
}

// 크기
extension GlassCircleButton {
    private enum Layout {
        static let size: CGFloat = 44
    }
}

#Preview {
    HStack {
        GlassCircleButton(title: "뒤로", systemImage: "chevron.left") {}
        GlassCircleButton(title: "완료", systemImage: "checkmark", isProminent: true) {}
    }
    .padding()
    .background(.orange)
}

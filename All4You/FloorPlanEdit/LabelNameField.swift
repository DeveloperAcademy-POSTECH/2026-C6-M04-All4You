// 공간·가구 이름을 고칠 때 이름 캡슐 자리에 띄우는 입력칸. 2D·3D 수정 화면이 함께 쓴다

import SwiftUI

/// 이름 캡슐(RoomLabelView·FurnitureLabelView)과 같은 모양의 입력칸. 커서는 주황
struct LabelNameField: View {
    /// 어느 캡슐을 고치는지. 캡슐 모양을 따른다
    enum Style {
        /// 공간 이름: 검은 캡슐, 흰 글자
        case room
        /// 가구 이름: 흰 캡슐, 검은 테두리
        case furniture
        /// 기타 스탬프 라벨: 주황 캡슐, 흰 글자 (StampKindLabelView 모양)
        case stamp
    }

    let style: Style
    /// 비어 있을 때 보이는 글자. 고치기 전 이름
    let placeholder: String
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    /// 키보드의 완료를 눌렀다
    let onSubmit: () -> Void
    /// 캡슐과 같은 배율 (LabelScale). 이름을 고치는 중에도 캡슐 크기가 그대로이게
    var scale: CGFloat = 1
    /// 넘으면 잘라 내는 글자 수. nil이면 제한이 없다
    var maxLength: Int? = nil

    var body: some View {
        switch style {
        case .room:
            field
                .font(AppTypography.subheadline)
                .foregroundStyle(.white)
                .padding(.horizontal, Layout.roomHorizontalPadding)
                .padding(.vertical, Layout.roomVerticalPadding)
                .background(.black, in: .capsule)
                .scaleEffect(scale)
        case .furniture:
            field
                .font(AppTypography.label)
                .foregroundStyle(.black)
                .padding(.horizontal, Layout.furnitureHorizontalPadding)
                .padding(.vertical, Layout.furnitureVerticalPadding)
                .background(.white, in: .capsule)
                .overlay { Capsule().stroke(.black, lineWidth: 1) }
                .scaleEffect(scale)
        case .stamp:
            field
                .font(.system(size: StampKindLabelView.Layout.fontSize, weight: .semibold))
                .foregroundStyle(.white)
                // 주황 바탕 위라 커서도 흰색
                .tint(.white)
                .padding(.horizontal, StampKindLabelView.Layout.horizontalPadding)
                .padding(.vertical, StampKindLabelView.Layout.verticalPadding)
                .background(.brand500, in: .capsule)
                .scaleEffect(scale)
        }
    }

    private var field: some View {
        TextField(placeholder, text: $text)
            .tint(.brand500)
            .multilineTextAlignment(.center)
            .fixedSize()
            .focused(isFocused)
            .submitLabel(.done)
            .onSubmit(onSubmit)
            .onChange(of: text) {
                if let maxLength, text.count > maxLength { text = String(text.prefix(maxLength)) }
            }
    }
}

// 레이아웃 값
extension LabelNameField {
    private enum Layout {
        /// RoomLabelView 캡슐과 같게 맞춘다
        static let roomHorizontalPadding: CGFloat = 16
        static let roomVerticalPadding: CGFloat = 8
        /// FurnitureLabelView 캡슐과 같게 맞춘다
        static let furnitureHorizontalPadding: CGFloat = 13
        static let furnitureVerticalPadding: CGFloat = 7.5
    }
}

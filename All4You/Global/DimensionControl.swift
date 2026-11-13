// 도면 위 치수·면적 글자를 켜고 끄는 버튼과, 보고 싶은 종류만 고르는 필터. 2D·3D 수정 화면이 함께 쓴다.
// 메인 도면 탭과 Export 화면도 같은 버튼과 DimensionDisplay를 쓰도록 만들어 두었다

import SwiftUI

/// 자 모양 유리 원 버튼. 누르면 치수 보기를 켜고 끄고, 켜져 있으면 위에 종류 필터가 펼쳐진다
struct DimensionControl: View {
    @Binding var display: DimensionDisplay

    var body: some View {
        VStack(alignment: .trailing, spacing: Layout.spacing) {
            if display.isShown {
                filter
                    .transition(.scale(scale: 0.9, anchor: .bottomTrailing).combined(with: .opacity))
            }
            toggleButton
        }
        .animation(.easeInOut(duration: Layout.animationDuration), value: display.isShown)
    }

    private var toggleButton: some View {
        Button {
            display.isShown.toggle()
        } label: {
            Image(systemName: display.isShown ? "ruler.fill" : "ruler")
                .font(.system(size: Layout.iconSize, weight: .semibold))
                .foregroundStyle(display.isShown ? Color.brand500 : Color.primary)
                .frame(width: Layout.buttonSize, height: Layout.buttonSize)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(Copy.buttonLabel)
        .accessibilityValue(display.isShown ? Copy.on : Copy.off)
    }

    /// 종류마다 체크 줄 하나. 눌러서 그 종류를 켜고 끈다
    private var filter: some View {
        VStack(alignment: .leading, spacing: Layout.rowSpacing) {
            ForEach(DimensionKind.allCases, id: \.self) { kind in
                let isOn = display.kinds.contains(kind)
                Button {
                    if isOn { display.kinds.remove(kind) } else { display.kinds.insert(kind) }
                } label: {
                    HStack(spacing: Layout.rowSpacing) {
                        Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isOn ? Color.brand500 : Color.secondary)
                        Text(kind.title)
                            .foregroundStyle(.primary)
                    }
                    .font(AppTypography.subheadline)
                    .padding(.horizontal, Layout.rowHorizontalPadding)
                    .padding(.vertical, Layout.rowVerticalPadding)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(Layout.filterPadding)
        .glassEffect(.regular, in: .rect(cornerRadius: Layout.filterCorner))
    }
}

// 종류 이름
extension DimensionKind {
    /// 필터에 보이는 이름
    // TEMP: Figma에 없는 화면이라 이름을 임의로 정함 — 디자인 확인 필요
    var title: String {
        switch self {
        case .room: "공간"
        case .wall: "벽"
        case .opening: "창문과 문"
        case .furniture: "가구"
        case .victim: "피해자"
        }
    }
}

// 레이아웃 값
extension DimensionControl {
    private enum Layout {
        // TEMP: Figma에 없는 버튼이라 모양·크기를 처음 맞춘 시야 버튼과 같게 임의로 정함 — 디자인 확인 필요
        static let buttonSize: CGFloat = 44
        static let iconSize: CGFloat = 17
        static let spacing: CGFloat = 8
        static let rowSpacing: CGFloat = 8
        static let rowHorizontalPadding: CGFloat = 8
        static let rowVerticalPadding: CGFloat = 6
        static let filterPadding: CGFloat = 8
        static let filterCorner: CGFloat = 22
        static let animationDuration = 0.2
    }
}

// 문구
extension DimensionControl {
    private enum Copy {
        static let buttonLabel = "치수·면적 보기"
        static let on = "켜짐"
        static let off = "꺼짐"
    }
}

#Preview {
    @Previewable @State var display = DimensionDisplay(isShown: true)
    DimensionControl(display: $display)
        .padding()
}

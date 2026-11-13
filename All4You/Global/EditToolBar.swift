// 2D·3D 수정 화면이 함께 쓰는 상단 도구 막대. 고른 도구를 표시하고, 발화지점·전기 도구는 누른 버튼 아래에 종류 옵션 줄을 펼친다

import SwiftUI

/// 도구 버튼과 막대 접기 버튼을 가진 상단 도구 막대
struct EditToolBar: View {
    @Binding var selectedTool: EditTool?
    var hiddenTools: Set<EditTool> = []
    /// 옵션 줄에서 고른 종류. 받으면 발화지점·전기 도구를 켰을 때 버튼 아래에 옵션 줄을 펼치고, nil이면 옵션 줄 없이 도구만 켠다
    var stampOption: Binding<StampOption?>? = nil

    @State private var isCollapsed = false

    /// 숨길 도구를 뺀 목록
    private var visibleTools: [EditTool] {
        EditTool.allCases.filter { !hiddenTools.contains($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.barSpacing) {
            bar
            optionRow
        }
    }

    private var bar: some View {
        // 버튼마다 따로 리퀴드 글래스를 쓰되, 한 묶음으로 그려 서로 가까워지면 물방울처럼 이어지게 한다
        GlassEffectContainer(spacing: Layout.barSpacing) {
            HStack(spacing: Layout.barSpacing) {
                // 접으면 도구가 모두 사라지고 '스탬프' 버튼 하나만 남는다.
                // 리퀴드 글래스는 잘라 내도 그려져서, 폭을 줄여 가리는 대신 도구를 화면에서 빼고 서서히 사라지게 한다
                if isCollapsed {
                    stampButton
                        .transition(foldTransition)
                } else {
                    foldingToolButtons
                        .transition(foldTransition)
                }
                collapseButton
            }
        }
    }

    /// 고른 도구를 한 번 더 누르면 선택을 푼다
    private func toggleTool(_ tool: EditTool) {
        selectedTool = selectedTool == tool ? nil : tool
        // 도구를 바꾸거나 끄면 고른 종류는 다시 고르게 한다
        stampOption?.wrappedValue = nil
    }

    /// 막대를 애니메이션과 함께 접고 편다
    private func toggleCollapsed() {
        withAnimation {
            isCollapsed.toggle()
        }
    }
}

// 종류 옵션 줄
extension EditToolBar {
    /// 고른 도구 버튼 바로 아래에 펼치는 종류 옵션 줄. 버튼에서 갈라져 나오는 것처럼 버튼 자리에서 커지며 나타난다
    @ViewBuilder
    private var optionRow: some View {
        if !isCollapsed, let stampOption, let tool = selectedTool, !tool.stampOptions.isEmpty,
           let index = visibleTools.firstIndex(of: tool) {
            GlassEffectContainer(spacing: Layout.optionSpacing) {
                HStack(spacing: Layout.optionSpacing) {
                    ForEach(tool.stampOptions, id: \.self) { option in
                        optionButton(option, selection: stampOption)
                    }
                }
            }
            // 누른 버튼의 왼쪽 끝에 맞춘다
            .padding(.leading, CGFloat(index) * (Layout.toolButtonWidth + Layout.barSpacing))
            .transition(.scale(scale: 0.5, anchor: .topLeading).combined(with: .opacity))
        }
    }

    private func optionButton(_ option: StampOption, selection: Binding<StampOption?>) -> some View {
        let isSelected = selection.wrappedValue == option
        return Button {
            selection.wrappedValue = option
        } label: {
            Text(option.title)
                .font(AppTypography.subheadline)
                .foregroundStyle(isSelected ? .white : .black)
                .padding(.horizontal, Layout.optionHorizontalPadding)
                .frame(height: Layout.optionHeight)
                .contentShape(Capsule())
                // TEMP: Figma에 없어 도구 버튼과 같은 리퀴드 글래스 캡슐로 임시로 정함
                .glassEffect(isSelected ? .regular.tint(.brand500).interactive() : .regular.interactive(), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// 서브 뷰
extension EditToolBar {
    /// 도구 버튼 묶음. 접으면 화살표 버튼 쪽(오른쪽)으로 모이며 사라진다
    private var foldingToolButtons: some View {
        HStack(spacing: Layout.barSpacing) {
            ForEach(visibleTools, id: \.self) { tool in
                toolButton(for: tool)
            }
        }
    }

    /// 접고 펼 때 버튼이 오른쪽 끝에서 작아지며 사라지고 나타난다
    private var foldTransition: AnyTransition {
        .scale(scale: 0.6, anchor: .trailing).combined(with: .opacity)
    }
    
    // 한 개의 도구 버튼
    private func toolButton(for tool: EditTool) -> some View {
        let isSelected = selectedTool == tool

        return Button {
            toggleTool(tool)
        } label: {
            toolLabel(for: tool, isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// 접힌 막대에 남는 버튼. 누르면 막대를 다시 편다
    private var stampButton: some View {
        Button {
            toggleCollapsed()
        } label: {
            buttonLabel(title: Copy.stamp, iconName: "seal", isSelected: false)
        }
        .buttonStyle(.plain)
        .accessibilityHint(Copy.expand)
    }

    private func toolLabel(for tool: EditTool, isSelected: Bool) -> some View {
        buttonLabel(title: tool.title, iconName: tool.iconName, isSelected: isSelected)
    }

    private func buttonLabel(title: String, iconName: String, isSelected: Bool) -> some View {
        VStack(spacing: Layout.labelSpacing) {
            Image(systemName: iconName)
                .font(AppTypography.title3)
            Text(title)
                .font(AppTypography.label)
        }
        .foregroundStyle(isSelected ? .white : .black)
        .frame(width: Layout.toolButtonWidth, height: Layout.toolButtonHeight)
        .contentShape(Capsule())
        // 고른 도구는 주황 틴트, 나머지는 투명한 리퀴드 글래스
        .glassEffect(isSelected ? .regular.tint(.brand500).interactive() : .regular.interactive(), in: Capsule())
    }
    
    // 접기 펼치기 버튼
    private var collapseButton: some View {
        Button {
            toggleCollapsed()
        } label: {
            Label(
                isCollapsed ? Copy.expand : Copy.collapse,
                systemImage: "chevron.left"
            )
            .labelStyle(.iconOnly)
            // 화살표 기호를 바꾸면 애니메이션 중에 배경과 따로 움직이므로, 같은 기호를 돌려서 방향만 바꾼다
            .rotationEffect(.degrees(isCollapsed ? 180 : 0))
            .foregroundStyle(.primary)
            .frame(width: Layout.collapseButtonWidth, height: Layout.toolButtonHeight)
            .contentShape(Capsule())
            .glassEffect(.regular.interactive(), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

// 크기
extension EditToolBar {
    private enum Layout {
        static let barSpacing: CGFloat = 8
        static let labelSpacing: CGFloat = 2
        static let toolButtonWidth: CGFloat = 76
        static let toolButtonHeight: CGFloat = 54
        static let collapseButtonWidth: CGFloat = 28
        static let optionSpacing: CGFloat = 6
        static let optionHeight: CGFloat = 36
        static let optionHorizontalPadding: CGFloat = 14
    }
}

// 문구
extension EditToolBar {
    private enum Copy {
        static let stamp = "스탬프"
        static let collapse = "도구 막대 접기"
        static let expand = "도구 막대 펼치기"
    }
}

#Preview {
    @Previewable @State var selectedTool: EditTool? = .outlet
    @Previewable @State var stampOption: StampOption?

    VStack(alignment: .leading) {
        EditToolBar(selectedTool: $selectedTool, stampOption: $stampOption)
        EditToolBar(selectedTool: $selectedTool, hiddenTools: [.roomName, .furniture, .door])
    }
}

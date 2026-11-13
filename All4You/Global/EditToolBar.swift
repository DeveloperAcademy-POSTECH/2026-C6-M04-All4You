// 2D·3D 수정 화면이 함께 쓰는 상단 도구 막대. 고른 도구를 표시하고, 발화지점·전기 도구는 누르면 버튼에서 리퀴드 글래스가 갈라져 나오며 종류 옵션을 보여 준다

import SwiftUI

/// 도구 버튼과 막대 접기 버튼을 가진 상단 도구 막대
struct EditToolBar: View {
    @Binding var selectedTool: EditTool?
    var hiddenTools: Set<EditTool> = []
    /// 옵션 줄에서 고른 종류. 받으면 발화지점·전기를 누를 때 버튼 아래로 옵션이 펼쳐지고, 종류를 고르면 옵션이 사라지고 버튼 이름이 고른 종류로 바뀐다. nil이면 다른 도구처럼 눌러 켜고 끄기만 한다
    var stampOption: Binding<StampOption?>? = nil

    @State private var isCollapsed = false
    /// 리퀴드 글래스 옵션을 같은 묶음의 글래스로 이어 주는 이름 공간
    @Namespace private var glassNamespace

    /// 숨길 도구를 뺀 목록
    private var visibleTools: [EditTool] {
        EditTool.allCases.filter { !hiddenTools.contains($0) }
    }

    var body: some View {
        // 버튼마다 따로 리퀴드 글래스를 쓰되, 한 묶음으로 그려 서로 가까워지면 물방울처럼 이어지게 한다
        GlassEffectContainer(spacing: Layout.barSpacing) {
            VStack(alignment: .leading, spacing: Layout.barSpacing) {
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
                optionRow
            }
        }
    }

    /// 고른 도구를 한 번 더 누르면 선택을 푼다
    private func toggleTool(_ tool: EditTool) {
        selectedTool = selectedTool == tool ? nil : tool
    }

    /// 도구 버튼을 눌렀다. 종류를 고르는 도구는 버튼에서 옵션이 갈라져 나오고, 종류를 고른 뒤 다시 누르면 옵션이 다시 펼쳐지고, 옵션이 펼쳐진 채 누르면 도구가 꺼진다
    private func tapTool(_ tool: EditTool) {
        updateTools {
            guard let stampOption, !tool.stampOptions.isEmpty else {
                toggleTool(tool)
                return
            }
            if selectedTool == tool {
                if stampOption.wrappedValue == nil {
                    selectedTool = nil
                } else {
                    stampOption.wrappedValue = nil
                }
            } else {
                selectedTool = tool
                stampOption.wrappedValue = nil
            }
        }
    }

    /// 옵션을 골랐다. 바로 도구가 켜지고(옵션은 사라짐), 버튼 이름이 고른 종류로 바뀐다.
    /// 이름은 스탬프를 놓아 도구가 꺼질 때까지 유지된다
    private func pickOption(_ option: StampOption, for tool: EditTool) {
        updateTools {
            selectedTool = tool
            stampOption?.wrappedValue = option
        }
    }

    /// 도구·종류를 바로 바꾼다. 버튼은 곧바로 켜지고 이름이 바뀐다
    private func updateTools(_ change: () -> Void) {
        withAnimation(Layout.morph) { change() }
    }

    /// 종류를 고르는 도구가 켜져 있고 아직 종류를 고르지 않아 옵션 줄을 펼쳐야 하는지
    private var wantsOptionRow: Bool {
        guard !isCollapsed, let stampOption, stampOption.wrappedValue == nil,
              let tool = selectedTool, !tool.stampOptions.isEmpty else { return false }
        return visibleTools.contains(tool)
    }

    /// 막대를 애니메이션과 함께 접고 편다
    private func toggleCollapsed() {
        withAnimation {
            isCollapsed.toggle()
        }
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
            tapTool(tool)
        } label: {
            toolLabel(for: tool, isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// 종류를 고르는 도구가 켜져 있고 아직 종류를 고르지 않았을 때, 그 버튼 바로 아래로 펼쳐지는 옵션 줄.
    /// 같은 리퀴드 글래스 묶음 안이라 시스템 글래스 전환(materialize)으로 나타나고 사라진다
    @ViewBuilder
    private var optionRow: some View {
        if wantsOptionRow, let tool = selectedTool, let index = visibleTools.firstIndex(of: tool) {
            HStack(spacing: Layout.optionSpacing) {
                ForEach(tool.stampOptions, id: \.self) { option in
                    Button {
                        pickOption(option, for: tool)
                    } label: {
                        Text(option.title)
                            .font(AppTypography.subheadline)
                            .foregroundStyle(.black)
                            .padding(.horizontal, Layout.optionHorizontalPadding)
                            .frame(height: Layout.optionHeight)
                            .contentShape(Capsule())
                            .glassEffect(.regular.interactive(), in: Capsule())
                            .glassEffectID("option.\(String(describing: option))", in: glassNamespace)
                            // 버튼 속으로 합쳐지는 모양(matchedGeometry)은 사라진 뒤에도 옵션 글자가 주황 버튼 안에 얼룩으로 한동안 비쳐서,
                            // 시스템 기본 글래스 전환 중 제자리에서 나타나고 사라지는 materialize를 쓴다
                            .glassEffectTransition(.materialize)
                    }
                    .buttonStyle(.plain)
                }
            }
            // 누른 버튼의 왼쪽 끝에 맞춘다
            .padding(.leading, CGFloat(index) * (Layout.toolButtonWidth + Layout.barSpacing))
        }
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

    /// 이 도구에서 고른 종류. 고르지 않았거나 다른 도구가 켜져 있으면 nil
    private func pickedOption(of tool: EditTool) -> StampOption? {
        selectedTool == tool ? stampOption?.wrappedValue : nil
    }

    /// 종류를 고른 도구는 스탬프를 놓아 꺼질 때까지 고른 종류 이름으로 보인다(발화지점 → 방화)
    private func toolLabel(for tool: EditTool, isSelected: Bool) -> some View {
        let title = pickedOption(of: tool)?.title ?? tool.title
        return buttonLabel(title: title, iconName: tool.iconName, isSelected: isSelected)
            // 옵션이 이 버튼에서 갈라져 나오고 다시 합쳐지도록 버튼마다 이름을 붙인다
            .glassEffectID("tool.\(String(describing: tool))", in: glassNamespace)
    }

    private func buttonLabel(title: String, iconName: String, isSelected: Bool) -> some View {
        VStack(spacing: Layout.labelSpacing) {
            Image(systemName: iconName)
                .font(AppTypography.title3)
            Text(title)
                .font(AppTypography.label)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                // 이름이 바뀔 때 옛 글자와 새 글자가 겹쳐 보이지 않게 바로 바꾼다
                .animation(nil, value: title)
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
        /// 옵션이 갈라져 나오고 합쳐지는 움직임
        static let morph = Animation.smooth(duration: 0.3)
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

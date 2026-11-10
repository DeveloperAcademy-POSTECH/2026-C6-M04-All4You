// 2D·3D 수정 화면이 함께 쓰는 상단 도구 막대. 지금은 고른 도구를 표시만 한다

import SwiftUI

/// 도구 버튼과 막대 접기 버튼을 가진 상단 도구 막대
struct EditToolBar: View {
    @Binding var selectedTool: EditTool?
    var hiddenTools: Set<EditTool> = []

    @State private var isCollapsed = false

    /// 숨길 도구를 뺀 목록
    private var visibleTools: [EditTool] {
        EditTool.allCases.filter { !hiddenTools.contains($0) }
    }

    var body: some View {
        // 버튼마다 따로 리퀴드 글래스를 쓰되, 한 묶음으로 그려 서로 가까워지면 물방울처럼 이어지게 한다
        GlassEffectContainer(spacing: Layout.barSpacing) {
            HStack(spacing: 0) {
                // 접으면 도구가 모두 가려지고 '스탬프' 버튼 하나만 남는다
                if isCollapsed {
                    stampButton
                }
                foldingToolButtons
                collapseButton
                    .padding(.leading, Layout.barSpacing)
            }
        }
    }

    /// 고른 도구를 한 번 더 누르면 선택을 푼다
    private func toggleTool(_ tool: EditTool) {
        selectedTool = selectedTool == tool ? nil : tool
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
    /// 접을 때 버튼이 따로 흐려지지 않고, 화살표 버튼이 지나가는 자리에서 함께 가려지게 한다
    private var foldingToolButtons: some View {
        HStack(spacing: Layout.barSpacing) {
            ForEach(visibleTools, id: \.self) { tool in
                toolButton(for: tool)
            }
        }
        // 폭을 0으로 줄이고 넘친 부분을 잘라 낸다. 서랍을 닫듯 오른쪽부터 가려진다
        .frame(width: isCollapsed ? 0 : nil, alignment: .leading)
        .clipped()
        // 접힌 동안에는 가려진 버튼을 누르거나 VoiceOver가 읽지 않게 한다
        .allowsHitTesting(!isCollapsed)
        .accessibilityHidden(isCollapsed)
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

    VStack(alignment: .leading) {
        EditToolBar(selectedTool: $selectedTool)
        EditToolBar(selectedTool: $selectedTool, hiddenTools: [.roomName, .furniture, .door])
    }
}

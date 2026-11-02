// 2D·3D 수정 화면이 함께 쓰는 상단 도구 막대. 지금은 고른 도구를 표시만 한다

import SwiftUI

/// 도구 버튼과 막대 접기 버튼을 가진 상단 도구 막대
struct EditToolBar: View {
    @Binding var selectedTool: EditTool?
    var disabledTools: Set<EditTool> = []

    @State private var isCollapsed = false

    /// 접으면 가장 왼쪽 도구만 남긴다
    private var visibleTools: [EditTool] {
        isCollapsed ? Array(EditTool.allCases.prefix(1)) : EditTool.allCases
    }

    var body: some View {
        HStack(spacing: Layout.barSpacing) {
            toolButtons
            collapseButton
        }
    }

    /// 고른 도구를 한 번 더 누르면 선택을 푼다
    private func toggleTool(_ tool: EditTool) {
        selectedTool = selectedTool == tool ? nil : tool
    }
}

// 서브 뷰
extension EditToolBar {
    private var toolButtons: some View {
        ForEach(visibleTools, id: \.self) { tool in
            toolButton(for: tool)
        }
    }
    
    // 한 개의 도구 버튼
    private func toolButton(for tool: EditTool) -> some View {
        let isSelected = selectedTool == tool
        let isDisabled = disabledTools.contains(tool)

        return Button {
            toggleTool(tool)
        } label: {
            toolLabel(for: tool, isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? Layout.disabledOpacity : 1)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func toolLabel(for tool: EditTool, isSelected: Bool) -> some View {
        VStack(spacing: Layout.labelSpacing) {
            Image(systemName: tool.iconName)
                .font(.title3)
            Text(tool.title)
                .font(.caption2)
        }
        // TEMP: 팀 공용 색이 정해지면 바꿔야 함
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .frame(width: Layout.toolButtonWidth, height: Layout.toolButtonHeight)
        // TEMP: 팀 공용 색이 정해지면 바꿔야 함 (Figma 기준 선택 색은 주황색)
        .background(isSelected ? Color.blue : Color(uiColor: .systemGray6), in: Capsule())
    }
    
    // 접기 펼치기 버튼
    private var collapseButton: some View {
        Button {
            isCollapsed.toggle()
        } label: {
            Label(
                isCollapsed ? Copy.expand : Copy.collapse,
                systemImage: isCollapsed ? "chevron.right" : "chevron.left"
            )
            .labelStyle(.iconOnly)
            // TEMP: 팀 공용 색이 정해지면 바꿔야 함
            .foregroundStyle(Color.primary)
            .frame(width: Layout.collapseButtonWidth, height: Layout.toolButtonHeight)
            // TEMP: 팀 공용 색이 정해지면 바꿔야 함
            .background(Color(uiColor: .systemGray6), in: Capsule())
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
        static let disabledOpacity = 0.35
    }
}

// 문구
extension EditToolBar {
    private enum Copy {
        static let collapse = "도구 막대 접기"
        static let expand = "도구 막대 펼치기"
    }
}

#Preview {
    @Previewable @State var selectedTool: EditTool? = .electrical

    VStack(alignment: .leading) {
        EditToolBar(selectedTool: $selectedTool)
        EditToolBar(selectedTool: $selectedTool, disabledTools: [.roomName, .furniture])
    }
}

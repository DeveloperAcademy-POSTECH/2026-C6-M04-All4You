// 펜·지우개·손(획 선택) 도구 막대. 도면 스케치 화면과 2D 수정 화면이 함께 쓴다
// 화면 위에 .overlay로 얹으면 아래 가운데에 고정된다

import SwiftUI

/// 아래 도구 막대에서 고를 수 있는 도구
enum DrawingTool: String, CaseIterable, Identifiable {
    case pen = "펜"
    case eraser = "지우개"
    case hand = "획 선택"

    var id: Self { self }

    var icon: String {
        switch self {
        case .pen: "pencil"
        case .eraser: "eraser"
        case .hand: "hand.point.up.left"
        }
    }
}

/// 아래 가운데에 고정된 펜·지우개·손 막대
struct DrawingToolBar: View {
    @Binding var selectedTool: DrawingTool
    /// 위 스탬프 도구가 켜져 있어 펜·지우개가 잠시 쓸 수 없는 상태. 이때 펜·지우개의 고른 표시를 지운다
    var isPenAndEraserSuspended = false
    /// 도구 버튼을 눌렀다. 이미 고른 도구를 다시 눌러도 알린다
    var onSelect: ((DrawingTool) -> Void)? = nil

    var body: some View {
        toolbar
            .padding(.bottom, Layout.edgeInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }
}

// 서브 뷰
extension DrawingToolBar {
    /// 버튼을 가로로 놓는다
    private var toolbar: some View {
        HStack(spacing: Layout.spacing) {
            ForEach(DrawingTool.allCases) { tool in
                toolButton(tool)
            }
        }
        .padding(Layout.toolbarPadding)
        .glassEffect(.regular, in: Capsule())
        .contentShape(Capsule())
    }

    private func toolButton(_ tool: DrawingTool) -> some View {
        Button {
            selectedTool = tool
            onSelect?(tool)
        } label: {
            Image(systemName: tool.icon)
                .font(.system(size: Layout.iconSize))
                .frame(width: Layout.toolSize, height: Layout.toolSize)
                // 투명한 곳도 눌리게 해서 아이콘 글자 위를 정확히 누르지 않아도 바로 반응하게 한다
                .contentShape(Circle())
        }
        .buttonStyle(ToolButtonStyle(isHighlighted: isHighlighted(tool)))
        .accessibilityLabel(tool.rawValue)
        .accessibilityAddTraits(isHighlighted(tool) ? .isSelected : [])
    }

    /// 고른 표시를 보일 도구. 스탬프가 켜져 있으면 펜·지우개는 표시하지 않는다
    private func isHighlighted(_ tool: DrawingTool) -> Bool {
        selectedTool == tool && !(isPenAndEraserSuspended && tool != .hand)
    }
}

// 누르는 순간 바로 고른 표시를 보이는 버튼 모양. 손을 뗄 때까지 기다리지 않아 반응이 즉각적이다
extension DrawingToolBar {
    private struct ToolButtonStyle: ButtonStyle {
        let isHighlighted: Bool

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .background {
                    if isHighlighted || configuration.isPressed {
                        Circle().fill(Color.gray200)
                    }
                }
        }
    }
}

// 레이아웃 값
extension DrawingToolBar {
    private enum Layout {
        // TEMP: 실기기에서 보고 정한다
        static let toolSize: CGFloat = 56
        static let iconSize: CGFloat = 26
        static let toolbarPadding: CGFloat = 4
        static let spacing: CGFloat = 4
        /// 화면 가장자리에서 막대까지
        static let edgeInset: CGFloat = 32
    }
}

#Preview {
    @Previewable @State var selectedTool = DrawingTool.pen

    Color.white
        .overlay {
            DrawingToolBar(selectedTool: $selectedTool)
        }
}

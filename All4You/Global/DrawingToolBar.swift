// 펜·지우개·손(획 선택) 도구 막대. 도면 스케치 화면과 2D 수정 화면이 함께 쓴다
// 화면 위에 .overlay로 얹으면 아래 가운데에 놓이고, 끌어서 놓으면 가장 가까운 가장자리(왼쪽·아래·오른쪽)에 붙는다

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

/// 끌어서 옮길 수 있는 펜·지우개·손 막대
struct DrawingToolBar: View {
    @Binding var selectedTool: DrawingTool
    /// 위 스탬프 도구가 켜져 있어 펜·지우개가 잠시 쓸 수 없는 상태. 이때 펜·지우개의 고른 표시를 지운다
    var isPenAndEraserSuspended = false
    /// 도구 버튼을 눌렀다. 이미 고른 도구를 다시 눌러도 알린다
    var onSelect: ((DrawingTool) -> Void)? = nil

    @State private var toolbarPosition: ToolbarPosition = .bottom
    @GestureState private var toolbarDrag: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let anchor = toolbarPosition.anchor(in: size)
            toolbar
                .position(x: anchor.x + toolbarDrag.width, y: anchor.y + toolbarDrag.height)
                .simultaneousGesture(dragGesture(anchor: anchor, size: size))
        }
        .coordinateSpace(name: Layout.space)
    }

    /// 막대를 끌다가 놓으면 가장 가까운 가장자리에 붙인다
    private func dragGesture(anchor: CGPoint, size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .named(Layout.space))
            .updating($toolbarDrag) { value, offset, _ in
                offset = value.translation
            }
            .onEnded { value in
                let destination = CGPoint(
                    x: anchor.x + value.translation.width,
                    y: anchor.y + value.translation.height
                )
                toolbarPosition = ToolbarPosition.allCases.min {
                    $0.distance(to: destination, in: size) < $1.distance(to: destination, in: size)
                } ?? .bottom
            }
    }
}

// 서브 뷰
extension DrawingToolBar {
    /// 막대 방향에 맞춰 버튼을 가로 또는 세로로 놓는다
    private var toolbar: some View {
        let layout = toolbarPosition == .bottom
            ? AnyLayout(HStackLayout(spacing: Layout.spacing))
            : AnyLayout(VStackLayout(spacing: Layout.spacing))

        return layout {
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
                .frame(width: Layout.toolSize, height: Layout.toolSize)
                .background {
                    if isHighlighted(tool) {
                        Circle().fill(Color.gray200)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tool.rawValue)
        .accessibilityAddTraits(isHighlighted(tool) ? .isSelected : [])
    }

    /// 고른 표시를 보일 도구. 스탬프가 켜져 있으면 펜·지우개는 표시하지 않는다
    private func isHighlighted(_ tool: DrawingTool) -> Bool {
        selectedTool == tool && !(isPenAndEraserSuspended && tool != .hand)
    }
}

// 막대가 붙는 자리
extension DrawingToolBar {
    private enum ToolbarPosition: CaseIterable {
        case left, bottom, right

        /// 이 자리에 붙었을 때 막대 가운데 점
        func anchor(in size: CGSize) -> CGPoint {
            let centerInset = Layout.edgeInset + Layout.toolbarPadding + Layout.toolSize / 2
            switch self {
            case .left: return CGPoint(x: centerInset, y: size.height / 2)
            case .bottom: return CGPoint(x: size.width / 2, y: size.height - centerInset)
            case .right: return CGPoint(x: size.width - centerInset, y: size.height / 2)
            }
        }

        func distance(to point: CGPoint, in size: CGSize) -> CGFloat {
            let anchor = anchor(in: size)
            return hypot(point.x - anchor.x, point.y - anchor.y)
        }
    }
}

// 레이아웃 값
extension DrawingToolBar {
    private enum Layout {
        static let toolSize: CGFloat = 44
        static let toolbarPadding: CGFloat = 4
        static let spacing: CGFloat = 4
        /// 화면 가장자리에서 막대까지
        static let edgeInset: CGFloat = 32
        static let space = "drawingToolBar"
    }
}

#Preview {
    @Previewable @State var selectedTool = DrawingTool.pen

    Color.white
        .overlay {
            DrawingToolBar(selectedTool: $selectedTool)
        }
}

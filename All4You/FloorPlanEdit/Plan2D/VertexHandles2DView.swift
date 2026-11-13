// 2D에서 고른 벽의 양 끝 꼭짓점에 붙는 손잡이. 끌면 그 꼭짓점이 움직이고 붙은 벽이 함께 늘고 준다

import SwiftUI

/// 고른 벽의 양 끝에 하나씩 놓는 유리 원 손잡이
struct VertexHandles2DView: View {
    /// 손잡이를 놓을 꼭짓점 (Vertex.id)과 화면 점
    let handles: [(vertexId: String, point: CGPoint)]
    /// 끄는 손가락 자리를 잴 좌표 공간 이름 (point와 같은 공간)
    let coordinateSpace: String
    /// 끄는 동안 어느 꼭짓점을 어느 화면 점으로 끄는지 알린다
    let onDrag: (String, CGPoint) -> Void
    /// 손을 떼면 알린다
    let onDragEnded: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(handles, id: \.vertexId) { handle in
                self.handle(for: handle.vertexId)
                    .position(handle.point)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// 서브 뷰
extension VertexHandles2DView {
    // TEMP: 꼭짓점 손잡이 모양이 Figma에 없어 창문 크기 손잡이와 같은 모양을 임시로 쓴다
    private func handle(for vertexId: String) -> some View {
        Image(systemName: "arrow.up.left.and.arrow.down.right")
            .font(AppTypography.title3)
            .foregroundStyle(.brand500)
            .frame(width: Layout.handleSize, height: Layout.handleSize)
            // 누르면 커지는 유리 효과(.interactive())는 끄는 동안 손잡이가 커져 보여서 쓰지 않는다
            .glassEffect(.regular, in: .circle)
            .contentShape(.circle)
            .accessibilityLabel(Copy.move)
            .gesture(
                DragGesture(coordinateSpace: .named(coordinateSpace))
                    .onChanged { onDrag(vertexId, $0.location) }
                    .onEnded { _ in onDragEnded() }
            )
    }
}

// 레이아웃 값
extension VertexHandles2DView {
    /// 손잡이 지름 (pt). 화면이 손잡이 위에서 시작한 끌기를 가려낼 때도 쓴다
    static let handleSize: CGFloat = 44

    private enum Layout {
        static let handleSize = VertexHandles2DView.handleSize
    }
}

// 문구
extension VertexHandles2DView {
    private enum Copy {
        static let move = "모서리 옮기기"
    }
}

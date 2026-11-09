// 2D에서 고른 창문·문의 양 끝에 붙는 손잡이. 벽을 따라 끌면 그쪽 끝만 움직여 폭이 바뀐다 (2D에서는 높이는 바꾸지 않는다)

import SwiftUI

/// 벽 시작점 쪽·끝점 쪽 끝에 하나씩 놓는 유리 원 손잡이
struct OpeningHandles2DView: View {
    /// 창문·문의 벽 시작점 쪽 끝과 끝점 쪽 끝 (화면 점)
    let start: CGPoint
    let end: CGPoint
    /// 끄는 손가락 자리를 잴 좌표 공간 이름 (start·end와 같은 공간)
    let coordinateSpace: String
    /// 끄는 동안 어느 끝(wallStart·wallEnd)을 어느 화면 점으로 끄는지 알린다
    let onDrag: (WindowEdge, CGPoint) -> Void
    /// 손을 떼면 알린다
    let onDragEnded: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            handle(for: .wallStart)
                .position(start)
            handle(for: .wallEnd)
                .position(end)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// 벽 방향 (도). 양쪽 화살표를 벽과 나란히 돌릴 때 쓴다
    private var wallAngle: Double {
        atan2(end.y - start.y, end.x - start.x) * 180 / .pi
    }
}

// 서브 뷰
extension OpeningHandles2DView {
    private func handle(for edge: WindowEdge) -> some View {
        Image(systemName: "arrow.left.and.right")
            .font(AppTypography.title3)
            .foregroundStyle(.brand500)
            .rotationEffect(.degrees(wallAngle))
            .frame(width: Layout.handleSize, height: Layout.handleSize)
            // 누르면 커지는 유리 효과(.interactive())는 끄는 동안 손잡이가 커져 보여서 쓰지 않는다
            .glassEffect(.regular, in: .circle)
            .contentShape(.circle)
            .accessibilityLabel(Copy.resize)
            .gesture(
                DragGesture(coordinateSpace: .named(coordinateSpace))
                    .onChanged { onDrag(edge, $0.location) }
                    .onEnded { _ in onDragEnded() }
            )
    }
}

// 레이아웃 값
extension OpeningHandles2DView {
    private enum Layout {
        static let handleSize: CGFloat = 44
    }
}

// 문구
extension OpeningHandles2DView {
    private enum Copy {
        static let resize = "폭"
    }
}

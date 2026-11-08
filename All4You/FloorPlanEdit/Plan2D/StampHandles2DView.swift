// 2D에서 고른 스탬프의 테두리 모서리에 붙는 손잡이. 왼쪽 위 ✕는 지우고, 오른쪽 위 ↻는 끌어서 돌린다
// 스탬프가 돌면 테두리와 손잡이도 함께 돈다

import SwiftUI

/// ✕·↻ 손잡이. 돌릴 수 없는 스탬프(콘센트)는 yaw를 nil로 넘겨 ✕만 보인다
struct StampHandles2DView: View {
    /// 스탬프 가운데 (화면 점)
    let center: CGPoint
    /// 가운데에서 테두리 변까지 (pt)
    let halfSize: CGFloat
    /// 스탬프 방향 (도). nil이면 돌리는 손잡이를 두지 않는다
    let yaw: Double?
    /// 끄는 손가락 자리를 잴 좌표 공간 이름 (center와 같은 공간)
    let coordinateSpace: String
    let onDelete: () -> Void
    /// 돌리는 동안 새 방향(도)을 알린다
    let onRotate: (Double) -> Void
    /// 손을 떼면 알린다
    let onRotateEnded: () -> Void

    /// 돌리기를 시작할 때의 방향. 돌리는 동안 yaw가 바뀌어도 여기서부터 잰다
    @State private var startYaw: Double?

    var body: some View {
        ZStack(alignment: .topLeading) {
            deleteHandle
                .position(corner(x: -1, y: -1))
            if yaw != nil {
                handleIcon("arrow.clockwise")
                    .accessibilityLabel(Copy.rotate)
                    .position(corner(x: 1, y: -1))
                    .gesture(rotateGesture)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// 테두리 모서리의 화면 점. x·y는 -1(왼쪽·위) 또는 1(오른쪽·아래). 스탬프 방향만큼 가운데를 축으로 돌린다
    private func corner(x: CGFloat, y: CGFloat) -> CGPoint {
        let radians = (yaw ?? 0) * .pi / 180
        let dx = x * halfSize
        let dy = y * halfSize
        return CGPoint(
            x: center.x + dx * cos(radians) - dy * sin(radians),
            y: center.y + dx * sin(radians) + dy * cos(radians)
        )
    }

    /// 가운데에서 point를 본 각도 (도). 화면은 아래가 +y라 시계 방향으로 커진다
    private func angle(to point: CGPoint) -> Double {
        atan2(point.y - center.y, point.x - center.x) * 180 / .pi
    }
}

// 서브 뷰
extension StampHandles2DView {
    private var deleteHandle: some View {
        Button(action: onDelete) {
            handleIcon("xmark")
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Copy.delete)
    }

    /// 유리 원 안의 주황 아이콘. 스탬프 방향만큼 함께 돈다.
    /// 누르면 커지는 유리 효과(.interactive())는 끄는 동안 손잡이가 커져 보여서 쓰지 않는다
    private func handleIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(AppTypography.title3)
            .foregroundStyle(.brand500)
            .rotationEffect(.degrees(yaw ?? 0))
            .frame(width: Layout.handleSize, height: Layout.handleSize)
            .glassEffect(.regular, in: .circle)
            .contentShape(.circle)
    }

    /// 가운데를 축으로 손가락이 돈 각도만큼 스탬프를 돌린다
    private var rotateGesture: some Gesture {
        DragGesture(coordinateSpace: .named(coordinateSpace))
            .onChanged { value in
                guard let yaw else { return }
                let start = startYaw ?? yaw
                startYaw = start
                onRotate(start + angle(to: value.location) - angle(to: value.startLocation))
            }
            .onEnded { _ in
                startYaw = nil
                onRotateEnded()
            }
    }
}

// 레이아웃 값
extension StampHandles2DView {
    private enum Layout {
        static let handleSize: CGFloat = 44
    }
}

// 문구
extension StampHandles2DView {
    private enum Copy {
        static let delete = "삭제"
        static let rotate = "회전"
    }
}

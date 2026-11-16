// 도면 변환 중에 도면(또는 도면 그림) 위를 위아래로 훑는 주황 레이저 선
// 룸플랜·직접 그리기·외부 도면 가져오기 변환 화면이 같은 모양과 속도로 쓰도록 Global에 둔다

import SwiftUI

/// 화면 가로 전체를 가로지르는 주황 선. 위아래로 주황빛이 흐리게 번진다.
/// 범위(range) 안에서 위 끝과 아래 끝을 계속 오가며, 올려 둔 뷰 전체를 가로질러 그린다
struct ScanLaserView: View {
    /// 선이 오가는 세로 범위. 올려 둔 뷰 안의 좌표(pt)로, 보통 도면이 그려진 사각형의 위·아래 끝이다. 없으면 올려 둔 뷰의 위끝~아래끝
    var range: ClosedRange<CGFloat>?

    /// 선이 아래 끝으로 가는 중인지. 바뀔 때마다 선이 위아래로 오간다
    @State private var isScanningDown = false

    var body: some View {
        GeometryReader { proxy in
            let sweep = range ?? 0...proxy.size.height
            laserLine(width: proxy.size.width)
                .position(x: proxy.size.width / 2, y: isScanningDown ? sweep.upperBound : sweep.lowerBound)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            withAnimation(.easeInOut(duration: Layout.scanDuration).repeatForever(autoreverses: true)) {
                isScanningDown = true
            }
        }
    }
}

// 서브 뷰
extension ScanLaserView {
    /// 주황 선과 그 위아래로 번지는 빛
    private func laserLine(width: CGFloat) -> some View {
        Rectangle()
            .fill(Color.brand500)
            .frame(width: width, height: Layout.lineHeight)
            .background {
                LinearGradient(
                    colors: [Color.brand500.opacity(0), Color.brand500.opacity(Layout.glowOpacity), Color.brand500.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: Layout.glowHeight)
            }
    }
}

// 레이아웃 값
extension ScanLaserView {
    private enum Layout {
        static let lineHeight: CGFloat = 3
        /// 선 위아래로 번지는 주황빛의 전체 높이 (pt)
        static let glowHeight: CGFloat = 60
        static let glowOpacity = 0.25
        /// 선이 위에서 아래로 한 번 가는 시간 (초)
        static let scanDuration = 1.2
    }
}

#Preview {
    Color.gray100
        .frame(width: 320, height: 400)
        .overlay {
            ScanLaserView(range: 40...360)
        }
}

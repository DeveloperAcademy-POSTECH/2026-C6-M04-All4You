// 2D 도면을 3D로 변환하는 동안 보이는 로딩 화면. 흐린 도면 위를 주황 선이 위아래로 훑는다

import SwiftUI

/// 변환이 끝나면 onFinished로 알려 주는 로딩 화면
struct ConversionLoadingView: View {
    /// 흐리게 깔아 둘 도면
    let planData: PlanData
    let onFinished: () -> Void

    /// 주황 선이 아래 끝으로 가는 중인지. 바뀔 때마다 선이 위아래로 오간다
    @State private var isScanningDown = false

    var body: some View {
        GeometryReader { proxy in
            let fit = PlanScreen(plan: planData, in: proxy.size, fill: Layout.planFill)
            wallLines(fit: fit)
                .overlay(alignment: .topLeading) {
                    scanLine(width: proxy.size.width, fit: fit)
                }
        }
        .accessibilityElement()
        .accessibilityLabel(Copy.message)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            withAnimation(.easeInOut(duration: Layout.scanDuration).repeatForever(autoreverses: true)) {
                isScanningDown = true
            }
        }
        .task {
            await waitForConversion()
        }
    }
}

// 서브 뷰
extension ConversionLoadingView {
    /// 벽만 연한 회색 선으로 그린 도면. 가상 경계선은 그리지 않는다
    // TEMP: 2D 도면 그리기가 아직 없어 벽 선만 그림 — 2D 도면이 생기면 그것을 흐리게 깔도록 바꿈
    private func wallLines(fit: PlanScreen) -> some View {
        Canvas { context, _ in
            for wall in planData.walls where !wall.isVirtual {
                guard let line = planData.line(of: wall) else { continue }
                var path = Path()
                path.move(to: fit.point(line.start))
                path.addLine(to: fit.point(line.end))
                let width = max(fit.length(wall.thickness), Layout.minimumWallWidth)
                context.stroke(path, with: .color(Color.gray300), style: StrokeStyle(lineWidth: width, lineCap: .square))
            }
        }
    }

    /// 화면 가로 전체를 가로지르는 주황 선. 위아래로 주황빛이 흐리게 번진다
    private func scanLine(width: CGFloat, fit: PlanScreen) -> some View {
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
            .position(x: width / 2, y: isScanningDown ? fit.rect.maxY : fit.rect.minY)
    }
}

// 변환 대기
extension ConversionLoadingView {
    /// 변환이 끝나기를 기다렸다가 다음 화면으로 넘긴다
    // TEMP: 실제 변환이 아직 없어 화면을 볼 수 있게 정해진 시간만 기다림 — 실제 변환이 생기면 변환이 끝나는 시점으로 바꿈
    private func waitForConversion() async {
        try? await Task.sleep(for: Layout.minimumDuration)
        // 기다리는 중에 화면이 사라졌다면 다음 화면으로 넘어가지 않는다
        if Task.isCancelled { return }
        onFinished()
    }
}

// 레이아웃 값
extension ConversionLoadingView {
    private enum Layout {
        /// 화면에서 도면이 차지하는 몫 (가로·세로 중 꽉 차는 쪽 기준)
        static let planFill = 0.8
        /// 벽이 아주 얇아도 이만큼(pt)은 보이게
        static let minimumWallWidth = 1.0
        static let lineHeight: CGFloat = 3
        /// 선 위아래로 번지는 주황빛의 전체 높이 (pt)
        static let glowHeight: CGFloat = 60
        static let glowOpacity = 0.25
        /// 선이 위에서 아래로 한 번 가는 시간 (초)
        static let scanDuration = 1.2
        /// 로딩 화면을 보여 주는 시간
        static let minimumDuration = Duration.seconds(2)
    }
}

// 문구
extension ConversionLoadingView {
    private enum Copy {
        static let message = "도면을 변환하는 중"
    }
}

#Preview {
    NavigationStack {
        ConversionLoadingView(planData: DummyFloorPlan.planData, onFinished: {})
    }
}

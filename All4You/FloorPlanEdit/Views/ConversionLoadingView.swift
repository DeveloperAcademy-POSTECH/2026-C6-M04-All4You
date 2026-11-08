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
            let fit = planFit(in: proxy.size)
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
    private func wallLines(fit: PlanFit) -> some View {
        Canvas { context, _ in
            for wall in planData.walls where !wall.isVirtual {
                guard let line = planData.line(of: wall) else { continue }
                var path = Path()
                path.move(to: fit.point(line.start))
                path.addLine(to: fit.point(line.end))
                let width = max(wall.thickness * fit.scale, Layout.minimumWallWidth)
                context.stroke(path, with: .color(Color.gray300), style: StrokeStyle(lineWidth: width, lineCap: .square))
            }
        }
    }

    /// 화면 가로 전체를 가로지르는 주황 선. 위아래로 주황빛이 흐리게 번진다
    private func scanLine(width: CGFloat, fit: PlanFit) -> some View {
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

// 도면을 화면에 맞추기
extension ConversionLoadingView {
    /// 도면을 비율 그대로 화면 가운데에 놓은 자리
    private struct PlanFit {
        /// 꼭짓점을 모두 감싸는 사각형의 왼쪽 위 (도면 좌표, m)
        let minPoint: SIMD2<Double>
        /// 1m가 화면에서 몇 pt인지
        let scale: Double
        /// 도면이 그려지는 화면 사각형
        let rect: CGRect

        /// 도면 점 (m)을 화면 점으로
        func point(_ p: SIMD2<Double>) -> CGPoint {
            CGPoint(x: rect.minX + (p.x - minPoint.x) * scale, y: rect.minY + (p.y - minPoint.y) * scale)
        }
    }

    private func planFit(in size: CGSize) -> PlanFit {
        let xs = planData.vertices.map(\.x)
        let ys = planData.vertices.map(\.y)
        let minPoint = SIMD2(xs.min() ?? 0, ys.min() ?? 0)
        // 꼭짓점이 없거나 한 줄로만 있어도 0으로 나누지 않게 아주 작은 크기를 둔다
        let planWidth = max((xs.max() ?? 0) - minPoint.x, 0.1)
        let planHeight = max((ys.max() ?? 0) - minPoint.y, 0.1)
        let scale = min(size.width / planWidth, size.height / planHeight) * Layout.planFill
        let fitted = CGSize(width: planWidth * scale, height: planHeight * scale)
        let origin = CGPoint(x: (size.width - fitted.width) / 2, y: (size.height - fitted.height) / 2)
        return PlanFit(minPoint: minPoint, scale: scale, rect: CGRect(origin: origin, size: fitted))
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

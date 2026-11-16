// 2D 도면을 3D로 변환하는 동안 보이는 로딩 화면. 흐린 도면 위를 주황 선(Global의 ScanLaserView)이 위아래로 훑는다

import SwiftUI

/// 변환이 끝나면 onFinished로 알려 주는 로딩 화면
struct ConversionLoadingView: View {
    /// 흐리게 깔아 둘 도면
    let planData: PlanData
    let onFinished: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let fit = PlanScreen(plan: planData, in: proxy.size, fill: Layout.planFill)
            // 변환할 도면을 흐리게 깐다
            Plan2DView(planData: planData, screen: fit)
                .opacity(Layout.planOpacity)
                .overlay {
                    ScanLaserView(range: fit.rect.minY...fit.rect.maxY)
                }
        }
        .accessibilityElement()
        .accessibilityLabel(Copy.message)
        .navigationBarBackButtonHidden(true)
        .task {
            await waitForConversion()
        }
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
        /// 흐리게 깐 도면의 진하기
        static let planOpacity = 0.3
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

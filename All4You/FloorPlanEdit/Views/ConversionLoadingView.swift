// 2D 도면을 3D로 변환하는 동안 보이는 로딩 화면의 빈 틀

import SwiftUI

/// 변환이 끝나면 onFinished로 알려 주는 로딩 화면
struct ConversionLoadingView: View {
    let onFinished: () -> Void

    var body: some View {
        ProgressView(Copy.message)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationBarBackButtonHidden(true)
            .task {
                await waitForConversion()
            }
    }
}

// 변환 대기
extension ConversionLoadingView {
    /// 변환이 끝나기를 기다렸다가 다음 화면으로 넘긴다
    // TEMP: 실제 변환이 아직 없어 잠깐 기다린 뒤 넘어감 — 이슈 19에서 실제 변환 완료 시점으로 교체
    private func waitForConversion() async {
        try? await Task.sleep(for: .seconds(1))
        // 기다리는 중에 화면이 사라졌다면 다음 화면으로 넘어가지 않는다
        if Task.isCancelled { return }
        onFinished()
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
        ConversionLoadingView(onFinished: {})
    }
}

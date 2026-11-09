import SwiftUI

struct FloorPlanConversionResultView: View {
    let plan: FloorPlanConversion
    let address: String
    let onBack: () -> Void
    /// 저장을 누르면 변환 결과(서버 도면 JSON 포함)를 넘긴다. 받는 쪽이 평면도로 바꿔 저장한다
    let onSave: (FloorPlanConversion) -> Void

    @State private var showsSaveError = false

    private var title: String {
        plan.isSegmentationPreview ? "픽셀 예측 미리보기" : "변환 도면 확인"
    }

    var body: some View {
        Image(uiImage: plan.preview)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.white)
            .accessibilityLabel("변환된 도면")
            .navigationTitle(title)
            .navigationSubtitle(address)
            .navigationBarTitleDisplayMode(.inline)
            .bothSidesToolbar(
                leadingTitle: "뒤로 가기",
                trailingTitle: "저장",
                customLayout: true,
                barTitle: title,
                barSubtitle: address,
                onBack: onBack,
                onDone: save
            )
            .alert("도면 파일을 저장하지 못했습니다", isPresented: $showsSaveError) {
                Button("확인", role: .cancel) {}
            } message: {
                Text("다시 시도해 주세요.")
            }
    }

    private func save() {
        do {
            try plan.save()
            onSave(plan)
        } catch {
            showsSaveError = true
        }
    }
}

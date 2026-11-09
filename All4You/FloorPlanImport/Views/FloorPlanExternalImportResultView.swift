import SwiftUI

// 촬영, 앨범, 파일의 영역 조정 결과를 같은 방식으로 변환하고 저장한다.
struct FloorPlanExternalImportResultView: View {
    let image: UIImage
    let address: String
    let onBack: () -> Void
    /// 저장을 누르면 변환 결과(서버 도면 JSON 포함)를 넘긴다. 받는 쪽이 평면도로 저장하고, 실패하면 알림 문구를 돌려준다
    let onSave: (FloorPlanConversion) -> String?
    @State private var convertedPlan: FloorPlanConversion?
    @State private var isConverting = false
    @State private var errorMessage: String?

    var body: some View {
        let title: String
        if let convertedPlan {
            title = convertedPlan.isSegmentationPreview ? "픽셀 예측 미리보기" : "변환 도면 확인"
        } else {
            title = "스캔 결과 확인"
        }

        return Image(uiImage: convertedPlan?.preview ?? image)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.white)
            .overlay {
                if isConverting {
                    ProgressView("도면 변환 중")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .preferredColorScheme(.light)
            .navigationTitle(title)
            .navigationSubtitle(address)
            .navigationBarTitleDisplayMode(.inline)
            .bothSidesToolbar(
                leadingTitle: "뒤로 가기",
                trailingTitle: convertedPlan == nil ? "도면 변환" : "저장",
                isDoneDisabled: isConverting,
                customLayout: true,
                barTitle: title,
                barSubtitle: address,
                onBack: {
                    isConverting = false
                    if convertedPlan != nil {
                        convertedPlan = nil
                    } else {
                        onBack()
                    }
                },
                onDone: {
                    if let convertedPlan {
                        do {
                            try convertedPlan.save()
                            errorMessage = onSave(convertedPlan)
                        } catch {
                            errorMessage = "도면 파일을 저장하지 못했습니다. 다시 시도해 주세요."
                        }
                    } else {
                        isConverting = true
                    }
                }
            )
            .task(id: isConverting) {
                guard isConverting else { return }
                do {
                    let plan = try await FloorPlanConversion.request(image)
                    try Task.checkCancellation()
                    convertedPlan = plan
                } catch {
                    guard !Task.isCancelled else { return }
                    errorMessage = error.localizedDescription
                }
                isConverting = false
            }
            .alert("도면 처리 실패", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("확인", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
    }
}

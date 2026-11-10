import SwiftUI

// 촬영, 앨범, 파일의 영역 조정 결과를 같은 방식으로 변환하고 저장한다.
struct FloorPlanExternalImportResultView: View {
    let image: UIImage
    let address: String
    let onBack: () -> Void
    /// 변환이 끝나면 평면도를 저장하고, 실패하면 알림 문구를 돌려준다
    let onSave: (FloorPlanConversion) -> String?
    @State private var isConverting = false
    @State private var errorMessage: String?

    var body: some View {
        let title = "스캔 결과 확인"

        Image(uiImage: image)
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
                trailingTitle: "도면 변환",
                isDoneDisabled: isConverting,
                customLayout: true,
                barTitle: title,
                barSubtitle: address,
                onBack: {
                    isConverting = false
                    onBack()
                },
                onDone: { isConverting = true }
            )
            .task(id: isConverting) {
                guard isConverting else { return }
                do {
                    let plan = try await FloorPlanConversion.request(image)
                    try Task.checkCancellation()
                    errorMessage = onSave(plan)
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

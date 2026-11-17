import SwiftUI

// 촬영, 앨범, 파일에서 가져온 이미지를 확인한 뒤 고정 도면 결과로 이어 간다.
struct FloorPlanExternalImportResultView: View {
    let image: UIImage
    let address: String
    let onBack: () -> Void
    let onSave: () -> String?

    @State private var isConverting = false
    @State private var showsResult = false
    @State private var saveError: String?

    var body: some View {
        Group {
            if showsResult {
                FloorPlanDrawingResultView(
                    address: address,
                    onBack: { showsResult = false },
                    onSave: { saveError = onSave() }
                )
            } else {
                importPreview
            }
        }
        .task(id: isConverting) {
            guard isConverting else { return }
            do {
                try await Task.sleep(for: .seconds(3))
                try Task.checkCancellation()
            } catch {
                isConverting = false
                return
            }
            isConverting = false
            showsResult = true
        }
        .alert("도면 저장 실패", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
    }

    private var importPreview: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.white)
            .preferredColorScheme(.light)
            .overlay {
                if isConverting {
                    GeometryReader { proxy in
                        Color.white.opacity(0.6)
                            .overlay { ScanLaserView(range: imageVerticalRange(in: proxy.size)) }
                    }
                    .accessibilityElement()
                    .accessibilityLabel("도면 변환 중")
                }
            }
            .bothSidesToolbar(
                leadingTitle: "뒤로 가기",
                trailingTitle: "도면 변환",
                isDoneDisabled: isConverting,
                customLayout: true,
                barTitle: "스캔 결과 확인",
                barSubtitle: address,
                onBack: onBack,
                onDone: { isConverting = true }
            )
            .allowsHitTesting(!isConverting)
    }

    private func imageVerticalRange(in size: CGSize) -> ClosedRange<CGFloat> {
        guard image.size.width > 0, size.width > 0 else { return 0...size.height }
        let height = min(size.height, size.width * image.size.height / image.size.width)
        let top = (size.height - height) / 2
        return top...(top + height)
    }
}

import SwiftUI

/// 입력한 손그림과 무관하게 지정된 결과 이미지를 보여 준다.
struct FloorPlanDrawingResultView: View {
    let address: String
    let onBack: () -> Void
    let onSave: () -> Void

    var body: some View {
        Image("DrawingFloorPlanResult")
            .resizable()
            .scaledToFit()
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.white)
            .accessibilityLabel("방 1, 방 2, 욕실, 거실, 베란다와 침대 두 개, TV, 소파, 탁자가 있고 거실과 베란다 사이에 미닫이문이 있는 도면")
            .preferredColorScheme(.light)
            .bothSidesToolbar(
                trailingTitle: "저장",
                customLayout: true,
                barTitle: "도면 결과 확인",
                barSubtitle: address,
                onBack: onBack,
                onDone: onSave
            )
    }
}

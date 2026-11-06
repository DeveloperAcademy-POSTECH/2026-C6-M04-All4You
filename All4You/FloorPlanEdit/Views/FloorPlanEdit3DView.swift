// 3D 도면 수정 화면. 도면을 3D로 보여 준다. 스탬프·창문 수정은 아직 없다

import SwiftUI

/// 3D 도면을 고치는 화면
struct FloorPlanEdit3DView: View {
    /// 2D·3D 수정 화면과 메인이 함께 보는 도면
    @Binding var planData: PlanData
    let onBack: () -> Void
    let onDone: () -> Void

    @State private var selectedTool: EditTool?

    /// 3D에서 가구는 보기만 하고 공간 이름은 라벨로만 보여 주므로 두 도구를 숨긴다
    private let hiddenTools: Set<EditTool> = [.roomName, .furniture]

    var body: some View {
        FloorPlan3DView(planData: planData)
            .overlay(alignment: .topLeading) {
                toolBar
            }
            .navigationTitle(Copy.title)
            .navigationBarTitleDisplayMode(.inline)
            .bothSidesToolbar(onBack: onBack, onDone: onDone)
    }
}

// 서브 뷰
extension FloorPlanEdit3DView {
    private var toolBar: some View {
        EditToolBar(selectedTool: $selectedTool, hiddenTools: hiddenTools)
            .padding()
    }
}

// 문구
extension FloorPlanEdit3DView {
    private enum Copy {
        static let title = "3D 도면 수정"
    }
}

#Preview {
    @Previewable @State var planData = DummyFloorPlan.planData
    NavigationStack {
        FloorPlanEdit3DView(planData: $planData, onBack: {}, onDone: {})
    }
}

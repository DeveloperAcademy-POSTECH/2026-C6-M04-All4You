// 3D 도면 수정 화면. 도면을 3D로 보여 준다. 스탬프·창문 수정은 아직 없다

import SwiftUI

/// 3D 도면을 고치는 화면
struct FloorPlanEdit3DView: View {
    /// 2D·3D 수정 화면과 메인이 함께 보는 도면
    @Binding var planData: PlanData
    let onBack: () -> Void
    let onDone: () -> Void

    @State private var selectedTool: EditTool?
    /// 3D에서 눌러 고른 스탬프·창문
    @State private var selection: PlanSelection?

    /// 3D에서 가구는 보기만 하고 공간 이름은 라벨로만 보여 주므로 두 도구를 숨긴다
    private let hiddenTools: Set<EditTool> = [.roomName, .furniture]

    var body: some View {
        FloorPlan3DView(planData: planData, selection: selection, onTap: handleTap)
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

// 누른 자리 처리
extension FloorPlanEdit3DView {
    /// 스탬프 도구를 골랐으면 맞는 자리(발화지점·피해자는 바닥, 전기는 벽)에 놓고, 도구가 없으면 누른 것을 고른다.
    /// 도구는 놓은 뒤에도 켜져 있어서, 같은 버튼을 다시 누르거나 다른 도구를 고를 때까지 계속 놓을 수 있다.
    /// 방금 놓은 스탬프를 고른 상태로 둔다
    private func handleTap(_ tap: PlanTap?) {
        switch (selectedTool, tap) {
        case (nil, .element(let element)?):
            selection = element
        case (nil, _):
            selection = nil
        case (.ignitionPoint?, .floor(let point)?):
            selection = .marker(planData.addMarker(.ignitionPoint, at: point))
        case (.person?, .floor(let point)?):
            selection = .marker(planData.addMarker(.person, at: point))
        case (.outlet?, .wall(let wallId, let point, let height)?):
            guard let id = planData.addWallFixture(.outlet, wallId: wallId, at: point, height: height) else { return }
            selection = .wallFixture(id)
        default:
            break
        }
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

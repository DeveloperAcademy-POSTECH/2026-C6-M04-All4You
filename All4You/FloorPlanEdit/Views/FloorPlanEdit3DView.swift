// 3D 도면 수정 화면. 도면을 3D로 보여 주고, 스탬프를 놓고 옮기고 돌리고 복제·삭제하고, 창문을 달고 크기를 바꾸고 지운다

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
        FloorPlan3DView(planData: planData, selection: selection, onTap: handleTap, onEdit: handleEdit)
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
    /// 이미 놓인 스탬프·창문을 누르면 도구와 상관없이 그것을 고른다.
    /// 빈 곳은 스탬프 도구를 골랐으면 맞는 자리(발화지점·피해자는 바닥, 전기는 벽)에 놓고, 도구가 없으면 고른 것을 푼다.
    /// 도구는 놓은 뒤에도 켜져 있어서, 같은 버튼을 다시 누르거나 다른 도구를 고를 때까지 계속 놓을 수 있다.
    /// 방금 놓은 스탬프를 고른 상태로 둔다
    private func handleTap(_ tap: PlanTap?) {
        switch (selectedTool, tap) {
        case (_, .element(let element)?):
            selection = element
        case (nil, _):
            selection = nil
        case (let tool?, let tap?):
            selection = planData.place(tool, at: tap) ?? selection
        case (_?, nil):
            break
        }
    }

    /// 옮기거나 돌리거나 복제·삭제한 스탬프를 도면에 반영한다. 복제하면 새 것을, 지우면 아무것도 고르지 않은 상태로 둔다
    private func handleEdit(_ edit: PlanEdit) {
        selection = planData.apply(edit, selection: selection)
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

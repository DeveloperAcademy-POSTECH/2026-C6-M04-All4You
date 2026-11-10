// 3D 도면 수정 화면. 도면을 3D로 보여 주고, 스탬프를 놓고 옮기고 돌리고 복제·삭제하고, 창문을 달고 크기를 바꾸고 지운다

import SwiftUI

/// 3D 도면을 고치는 화면
struct FloorPlanEdit3DView: View {
    /// 2D·3D 수정 화면과 메인이 함께 보는 도면
    @Binding var planData: PlanData
    /// 2D 수정 화면과 함께 쓰는 되돌리기·다시 하기 기록
    @Binding var history: PlanHistory
    /// 위 도구 막대에서 켠 스탬프 도구. 2D·3D 전환 화면이 함께 들고 있어서 전환해도 이어진다
    @Binding var selectedTool: EditTool?
    let onBack: () -> Void
    let onDone: () -> Void

    /// 3D에서 눌러 고른 스탬프·창문
    @State private var selection: PlanSelection?

    /// 3D에서 가구는 만들 수 없고(고른 가구만 옮기고 돌리고 크기를 바꿈) 공간 이름은 라벨로만 보여 주므로 두 도구를 숨긴다
    static let hiddenTools: Set<EditTool> = [.roomName, .furniture]

    var body: some View {
        FloorPlan3DView(planData: planData, selection: selection, onTap: handleTap, onEdit: handleEdit, isStampToolActive: selectedTool != nil)
            .overlay(alignment: .topLeading) {
                toolBar
            }
            .bothSidesToolbar(customLayout: true, barTitle: Copy.title, trailingAccessory: AnyView(undoRedo), onBack: onBack, onDone: onDone)
    }
}

// 서브 뷰
extension FloorPlanEdit3DView {
    private var toolBar: some View {
        EditToolBar(selectedTool: $selectedTool, hiddenTools: Self.hiddenTools)
            .padding()
    }

    /// 되돌리면 고른 것이 사라졌을 수 있어 고르기를 푼다
    private var undoRedo: some View {
        UndoRedoCapsule(history: $history, planData: $planData) {
            selection = nil
        }
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
    @Previewable @State var history = PlanHistory()
    @Previewable @State var selectedTool: EditTool?
    NavigationStack {
        FloorPlanEdit3DView(planData: $planData, history: $history, selectedTool: $selectedTool, onBack: {}, onDone: {})
    }
}

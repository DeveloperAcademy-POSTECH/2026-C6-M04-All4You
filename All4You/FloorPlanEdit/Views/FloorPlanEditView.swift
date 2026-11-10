// 도면 수정 화면. 아래 2D·3D 전환 막대로 2D 수정과 3D 수정을 오가며 고친다. 완료(✓)는 두 화면 모두 변환 화면을 거쳐 메인으로 간다

import SwiftUI

/// 2D 수정과 3D 수정을 감싸는 화면. 도면·되돌리기 기록·켜 둔 스탬프 도구는 두 화면이 함께 쓴다
struct FloorPlanEditView: View {
    /// 2D·3D 수정 화면과 메인이 함께 보고 고치는 도면
    @Binding var planData: PlanData
    /// 2D·3D가 함께 쓰는 되돌리기·다시 하기 기록
    @Binding var history: PlanHistory
    let onBack: () -> Void
    let onDone: () -> Void

    @State private var dimension = PlanDimension.twoD
    /// 켜 둔 스탬프 도구. 전환해도 이어지되, 3D에 없는 도구는 3D로 갈 때 끈다
    @State private var selectedTool: EditTool?

    var body: some View {
        Group {
            switch dimension {
            case .twoD:
                FloorPlanEdit2DView(planData: $planData, history: $history, selectedTool: $selectedTool, onBack: onBack, onDone: onDone)
            case .threeD:
                FloorPlanEdit3DView(planData: $planData, history: $history, selectedTool: $selectedTool, onBack: onBack, onDone: onDone)
            }
        }
        .overlay(alignment: .bottom) {
            DimensionPicker(selection: $dimension)
                .padding()
        }
        .onChange(of: dimension) {
            // 고른 스탬프·벽·이름 선택은 화면마다 따로라 전환하면 풀린다. 켜 둔 도구는 3D에 없는 것(공간라벨·가구라벨)만 끈다
            if let selectedTool, dimension == .threeD, FloorPlanEdit3DView.hiddenTools.contains(selectedTool) {
                self.selectedTool = nil
            }
        }
    }
}

#Preview {
    @Previewable @State var planData = DummyFloorPlan.planData
    @Previewable @State var history = PlanHistory()

    NavigationStack {
        FloorPlanEditView(planData: $planData, history: $history, onBack: {}, onDone: {})
    }
}

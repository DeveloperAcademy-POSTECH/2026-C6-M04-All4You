// 상단 바 ✓ 옆의 되돌리기·다시 하기 유리 캡슐. 2D·3D 수정 화면이 함께 쓴다

import SwiftUI

/// ↶ ↷ 두 버튼. 할 수 없는 쪽은 흐리게 하고 누를 수 없게 한다
struct UndoRedoCapsule: View {
    @Binding var history: PlanHistory
    @Binding var planData: PlanData
    /// 도면을 되돌리거나 다시 한 뒤 화면이 고른 것·미리 보기를 비울 때 부른다
    var onRestore: () -> Void = {}

    var body: some View {
        HStack(spacing: 0) {
            button(Copy.undo, icon: "arrow.uturn.backward", isEnabled: history.canUndo, action: undo)
            button(Copy.redo, icon: "arrow.uturn.forward", isEnabled: history.canRedo, action: redo)
        }
        .frame(width: Layout.width, height: Layout.height)
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    private func button(_ title: String, icon: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: Layout.iconSize, weight: .semibold))
                .foregroundStyle(isEnabled ? Color.black : Color.gray400)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(title)
    }

    private func undo() {
        guard let previous = history.undo(from: planData) else { return }
        onRestore()
        planData = previous
    }

    private func redo() {
        guard let next = history.redo(from: planData) else { return }
        onRestore()
        planData = next
    }
}

// 레이아웃 값
extension UndoRedoCapsule {
    private enum Layout {
        static let width: CGFloat = 110
        static let height: CGFloat = 48
        static let iconSize: CGFloat = 17
    }
}

// 문구
extension UndoRedoCapsule {
    private enum Copy {
        static let undo = "되돌리기"
        static let redo = "다시 하기"
    }
}

#Preview {
    @Previewable @State var history = PlanHistory()
    @Previewable @State var planData = DummyFloorPlan.planData

    UndoRedoCapsule(history: $history, planData: $planData)
        .padding()
        .background(.white)
}

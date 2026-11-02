// 3D 도면 수정 화면의 빈 틀. 3D 표시와 수정은 이후 이슈에서 들어온다

import SwiftUI

/// 3D 도면을 고치는 화면
struct FloorPlanEdit3DView: View {
    let onBack: () -> Void
    let onDone: () -> Void

    @State private var selectedTool: EditTool?

    /// 3D에서 가구는 보기만 하고 공간 이름은 라벨로만 보여 주므로 두 도구를 막는다
    private let disabledTools: Set<EditTool> = [.roomName, .furniture]

    var body: some View {
        Text(Copy.placeholder)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.quaternary)
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
        EditToolBar(selectedTool: $selectedTool, disabledTools: disabledTools)
            .padding()
    }
}

// 문구
extension FloorPlanEdit3DView {
    private enum Copy {
        static let title = "3D 도면 수정"
        static let placeholder = "3D 도면 자리"
    }
}

#Preview {
    NavigationStack {
        FloorPlanEdit3DView(onBack: {}, onDone: {})
    }
}

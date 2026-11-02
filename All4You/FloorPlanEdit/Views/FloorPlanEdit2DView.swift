// 2D 도면 수정 화면의 빈 틀. 벽·스탬프·공간 이름 수정은 이후 이슈에서 들어온다

import SwiftUI

/// 2D 도면을 고치는 화면
struct FloorPlanEdit2DView: View {
    let onBack: () -> Void
    let onDone: () -> Void

    @State private var selectedTool: EditTool?

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
extension FloorPlanEdit2DView {
    private var toolBar: some View {
        EditToolBar(selectedTool: $selectedTool)
            .padding()
    }
}

// 문구
extension FloorPlanEdit2DView {
    private enum Copy {
        static let title = "2D 도면 수정"
        static let placeholder = "2D 도면 자리"
    }
}

#Preview {
    NavigationStack {
        FloorPlanEdit2DView(onBack: {}, onDone: {})
    }
}

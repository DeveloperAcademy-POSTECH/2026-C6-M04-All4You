// 3D 도면 수정 화면의 빈 틀. 3D 표시와 수정은 이후 이슈에서 들어온다

import SwiftUI

/// 3D 도면을 고치는 화면
struct FloorPlanEdit3DView: View {
    let onBack: () -> Void
    let onDone: () -> Void

    var body: some View {
        Text(Copy.placeholder)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.quaternary)
            .navigationTitle(Copy.title)
            .navigationBarTitleDisplayMode(.inline)
            .bothSidesToolbar(onBack: onBack, onDone: onDone)
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

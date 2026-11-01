// 사진 업로드 화면의 빈 틀. 도면 미리보기와 선택지, 권한 요청은 이후 이슈에서 들어온다

import SwiftUI

/// 사진을 촬영하거나 가져오는 방법을 고르는 화면
struct PhotoUploadView: View {
    let onBack: () -> Void

    var body: some View {
        Text(Copy.placeholder)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.quaternary)
            .navigationTitle(Copy.title)
            .navigationBarTitleDisplayMode(.inline)
            .backOnlyToolbar(onBack: onBack)
    }
}

// 문구
extension PhotoUploadView {
    private enum Copy {
        static let title = "사진업로드"
        static let placeholder = "사진 업로드 자리"
    }
}

#Preview {
    NavigationStack {
        PhotoUploadView(onBack: {})
    }
}

// 사건 작업 메인 화면의 빈 틀. 보기 옵션·2D/3D 전환·탭은 이후 이슈에서 들어온다

import SwiftUI

/// 도면·앨범·메모를 오가며 사건을 작업하는 화면
struct CaseMainView: View {
    let onBack: () -> Void
    let onEdit: () -> Void
    let onAddPhoto: () -> Void

    var body: some View {
        Text(Copy.placeholder)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.quaternary)
            .navigationTitle(Copy.title)
            .navigationBarTitleDisplayMode(.inline)
            .backOnlyToolbar(onBack: onBack)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    editButton
                    addPhotoButton
                }
            }
    }
}

// 서브 뷰
extension CaseMainView {
    private var editButton: some View {
        Button(Copy.edit, action: onEdit)
    }

    private var addPhotoButton: some View {
        Button(Copy.addPhoto, action: onAddPhoto)
    }
}

// 문구
extension CaseMainView {
    private enum Copy {
        static let title = "사건 작업"
        static let placeholder = "사건 작업 메인 자리"
        static let edit = "수정"
        static let addPhoto = "사진추가"
    }
}

#Preview {
    NavigationStack {
        CaseMainView(onBack: {}, onEdit: {}, onAddPhoto: {})
    }
}

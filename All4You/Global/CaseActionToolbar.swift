// 사건 화면 상단 바 오른쪽 버튼 묶음: 메모 추가·사진추가 캡슐, 수정, 내보내기.
// 사건명·차수(CaseTitleToolbar), 뒤로가기·완료(Global/Toolbar.swift)와 따로 붙여 화면마다 골라 쓴다

import SwiftUI

extension View {
    /// 상단 바 오른쪽에 버튼 묶음을 붙인다. 버튼마다 할 일은 화면이 넘겨준다.
    /// 한 묶음(ToolbarItemGroup)의 버튼은 유리 캡슐 하나를 함께 쓰므로,
    /// 메모 추가·사진추가는 한 캡슐에 두고 수정·내보내기는 ToolbarSpacer로 떼어 각자 원으로 둔다
    func caseActionToolbar(
        onAddMemo: @escaping () -> Void,
        onTakePhoto: @escaping () -> Void,
        onImportPhoto: @escaping () -> Void,
        onEdit: @escaping () -> Void,
        onExport: @escaping () -> Void
    ) -> some View {
        toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(CaseActionCopy.addMemo, systemImage: "plus.bubble", action: onAddMemo)
                AddPhotoButton(onTakePhoto: onTakePhoto, onImportPhoto: onImportPhoto)
            }
            ToolbarSpacer(.fixed, placement: .primaryAction)
            ToolbarItem(placement: .primaryAction) {
                Button(CaseActionCopy.edit, systemImage: "pencil", action: onEdit)
            }
            ToolbarSpacer(.fixed, placement: .primaryAction)
            ToolbarItem(placement: .primaryAction) {
                Button(CaseActionCopy.export, systemImage: "square.and.arrow.up", action: onExport)
            }
        }
    }
}

/// 사진추가 아이콘을 누르면 아이콘 아래로 사진을 찍을지 불러올지 고르는 작은 창이 뜬다.
/// 기본 Menu는 상단 바 버튼을 덮으며 펼쳐져서, 버튼이 그대로 보이도록 팝오버를 쓴다
private struct AddPhotoButton: View {
    let onTakePhoto: () -> Void
    let onImportPhoto: () -> Void

    @State private var isOpen = false

    var body: some View {
        Button(CaseActionCopy.addPhoto, systemImage: "photo.badge.plus") {
            isOpen = true
        }
        .popover(isPresented: $isOpen, arrowEdge: .top) {
            photoOptions
        }
    }

    /// 팝오버 안의 캡슐 버튼 두 개. 하나를 고르면 창을 닫고 화면이 넘겨준 일을 한다
    private var photoOptions: some View {
        VStack(spacing: Layout.optionSpacing) {
            optionButton(CaseActionCopy.takePhoto, systemImage: "camera", action: onTakePhoto)
            optionButton(CaseActionCopy.importPhoto, systemImage: "photo.on.rectangle", action: onImportPhoto)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        // Figma의 기본 버튼은 애플 기본 회색 바탕에 검은 글자라 애플 기본 색을 쓴다.
        // 누른 버튼의 주황 바탕은 창이 바로 닫혀 잠깐만 보이므로 만들지 않는다
        .tint(.primary)
        // 두 버튼을 긴 쪽 글자 폭에 맞춰 같은 너비로 만든다
        .fixedSize(horizontal: true, vertical: false)
        .padding()
        // 좁은 화면에서도 아래에서 올라오는 시트로 바뀌지 않고 작은 창으로 뜨게 한다
        .presentationCompactAdaptation(.popover)
    }

    private func optionButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button {
            isOpen = false
            action()
        } label: {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
    }
}

// 크기
extension AddPhotoButton {
    private enum Layout {
        static let optionSpacing: CGFloat = 8
    }
}

// 문구. extension View 함수와 AddPhotoButton이 함께 쓰므로 파일 안 어디서나 쓸 수 있게 둔다
private enum CaseActionCopy {
    static let addMemo = "메모 추가"
    static let addPhoto = "사진추가"
    static let takePhoto = "사진 촬영하기"
    static let importPhoto = "사진 불러오기"
    static let edit = "수정"
    static let export = "내보내기"
}

#Preview {
    NavigationStack {
        Text("화면 내용")
            .caseActionToolbar(
                onAddMemo: {},
                onTakePhoto: {},
                onImportPhoto: {},
                onEdit: {},
                onExport: {}
            )
    }
}

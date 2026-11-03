// 사건 작업 메인 화면. 상단 바와 도면·앨범·메모 탭으로 구성된다

import SwiftUI

/// 도면·앨범·메모를 오가며 사건을 작업하는 화면
struct CaseMainView: View {
    // 뒤로가기, 편집하기(펜 아이콘)
    let onBack: () -> Void
    let onEdit: () -> Void

    // 탭을 오가도 고른 값이 남도록 탭이 아니라 이 화면이 기억한다
    @State private var photoFilter = PhotoFilter()
    @State private var dimension: FloorPlanTabView.Dimension = .twoD

    var body: some View {
        CaseTabView {
            withCaseToolbars(FloorPlanTabView(photoFilter: $photoFilter, dimension: $dimension))
        } album: {
            withCaseToolbars(emptyTab(Copy.albumPlaceholder))
        } memo: {
            withCaseToolbars(emptyTab(Copy.memoPlaceholder))
        }
    }
}

// 탭
extension CaseMainView {
    /// 탭마다 상단 바가 따로 있어서, 어느 탭에서든 같은 상단 바 버튼이 보이도록 각 탭 내용에 붙인다
    private func withCaseToolbars(_ content: some View) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .caseActionToolbar(
                onAddMemo: {
                    // TODO: 메모 추가
                },
                onTakePhoto: {
                    // TODO: 카메라 권한 확인과 요청 (이슈 23), 이후 사진 촬영 화면
                },
                onImportPhoto: {
                    // TODO: 사진 앱 권한 확인과 요청 (이슈 23), 이후 사진 불러오기 화면
                },
                onEdit: onEdit,
                onExport: {
                    // TODO: 내보내기
                }
            )
            .caseTitleToolbar(
                title: Copy.title,
                sessionNumber: Copy.sessionNumber,
                sessionNumbers: Copy.sessionNumbers,
                onSelectSession: { _ in
                    // TODO: 고른 조사 차수로 바꾸기
                },
                onAddSession: {
                    // TODO: 새 조사 차수 만들기
                }
            )
            // 나중에 붙인 toolbar의 버튼이 앞에 놓이므로, 뒤로가기가 맨 왼쪽에 오도록 backOnlyToolbar를 마지막에 붙인다
            .backOnlyToolbar(onBack: onBack)
    }

    /// 아직 내용이 없는 앨범·메모 탭의 빈 화면
    private func emptyTab(_ placeholder: String) -> some View {
        Text(placeholder)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.quaternary)
    }
}

// 문구
extension CaseMainView {
    private enum Copy {
        // TEMP: 사건 데이터가 생기기 전 임시 값 — 데이터 저장 방식이 정해지면 사건·차수 값으로 바꿔야 함
        // 이름은 ERD 필드를 따름: Investigation.title, InvestigationSession.sessionNumber
        static let title = "청암로 77"
        static let sessionNumber = 1
        static let sessionNumbers = [1, 2]

        static let albumPlaceholder = "앨범 자리"
        static let memoPlaceholder = "메모 자리"
    }
}

#Preview {
    CaseMainView(onBack: {}, onEdit: {})
}

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

    /// 사진추가 아래 작은 창(사진 촬영하기·사진 불러오기)이 떠 있는지
    @State private var isAddPhotoOptionsShown = false

    var body: some View {
        // 아이콘은 접근성/사이드바에 들어가는 역할이라 불필요하다는 피드백 오면 삭제 예정
        TabView {
            Tab(Copy.floorPlanTab, systemImage: "map") {
                FloorPlanTabView(photoFilter: $photoFilter, dimension: $dimension)
            }
            Tab(Copy.albumTab, systemImage: "photo.on.rectangle") {
                emptyTab(Copy.albumPlaceholder)
            }
            Tab(Copy.memoTab, systemImage: "note.text") {
                emptyTab(Copy.memoPlaceholder)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        // 나중에 붙인 toolbar의 버튼이 앞에 놓이므로, 뒤로가기가 맨 왼쪽에 오도록 backOnlyToolbar를 마지막에 붙인다
        .toolbar {
            caseTitle
            sessionMenu
            actionButtons
        }
        .backOnlyToolbar(onBack: onBack)
    }
}

// 상단 바
// TEMP: 협업 시 글로벌 상단 바로 교체 예정. 뒤로가기만 Global/Toolbar.swift를 쓰고 나머지는 이 화면에 둠
extension CaseMainView {
    /// 사건 제목과 생성 시각을 두 줄로 보여 준다
    private var caseTitle: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            VStack(alignment: .leading) {
                Text(Copy.title)
                    .font(AppTypography.headlineEmphasized)
                Text(Copy.createdAt)
                    .font(AppTypography.subheadline)
                    .foregroundStyle(.secondary)
            }
            // 상단 바가 이 칸을 좁게 잡아 제목이 "청…"으로 잘리므로 글자 길이만큼 자리를 차지하게 한다
            .fixedSize()
        }
        .sharedBackgroundVisibility(.hidden)
    }
    
    // 조사 차수
    private var sessionMenu: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                // TODO: 조사 차수 선택·추가 메뉴
            } label: {
                HStack(spacing: Layout.sessionLabelSpacing) {
                    Text(Copy.sessionNumber)
                    Image(systemName: "chevron.down")
                }
                .font(AppTypography.subheadline)
            }
        }
    }
    
    // 우측 기능도구들
    // 한 묶음(ToolbarItemGroup)의 버튼은 유리 캡슐 하나를 함께 쓰므로,
    // 메모 추가·사진추가는 한 캡슐에 두고 수정·내보내기는 ToolbarSpacer로 떼어 각자 원으로 둔다
    @ToolbarContentBuilder
    private var actionButtons: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            // 메모 작성
            Button(Copy.addMemo, systemImage: "plus.bubble") {
                // TODO: 메모 추가
            }
            addPhotoButton
        }
        ToolbarSpacer(.fixed, placement: .primaryAction)
        // 도면 수정
        ToolbarItem(placement: .primaryAction) {
            Button(Copy.edit, systemImage: "pencil", action: onEdit)
        }
        ToolbarSpacer(.fixed, placement: .primaryAction)
        // Export
        ToolbarItem(placement: .primaryAction) {
            Button(Copy.export, systemImage: "square.and.arrow.up") {
                // TODO: 내보내기
            }
        }
    }

    /// 사진추가 아이콘을 누르면 아이콘 아래로 사진을 찍을지 불러올지 고르는 작은 창이 뜬다.
    /// 기본 Menu는 상단 바 버튼을 덮으며 펼쳐져서, 버튼이 그대로 보이도록 팝오버를 쓴다
    private var addPhotoButton: some View {
        Button(Copy.addPhoto, systemImage: "photo.badge.plus") {
            isAddPhotoOptionsShown = true
        }
        .popover(isPresented: $isAddPhotoOptionsShown, arrowEdge: .top) {
            addPhotoOptions
        }
    }

    /// 팝오버 안의 캡슐 버튼 두 개. 하나를 고르면 창을 닫는다
    private var addPhotoOptions: some View {
        VStack(spacing: Layout.addPhotoOptionSpacing) {
            Button {
                isAddPhotoOptionsShown = false
                // TODO: 카메라 권한 확인과 요청 (이슈 23), 이후 사진 촬영 화면
            } label: {
                Label(Copy.takePhoto, systemImage: "camera")
                    .frame(maxWidth: .infinity)
            }
            Button {
                isAddPhotoOptionsShown = false
                // TODO: 사진 앱 권한 확인과 요청 (이슈 23), 이후 사진 불러오기 화면
            } label: {
                Label(Copy.importPhoto, systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
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
}

// 탭
extension CaseMainView {
    /// 아직 내용이 없는 앨범·메모 탭의 빈 화면
    private func emptyTab(_ placeholder: String) -> some View {
        Text(placeholder)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.quaternary)
    }
}

// 크기
extension CaseMainView {
    private enum Layout {
        static let sessionLabelSpacing: CGFloat = 4
        static let addPhotoOptionSpacing: CGFloat = 8
    }
}

// 문구
extension CaseMainView {
    private enum Copy {
        // TEMP: 사건 데이터가 생기기 전 임시 문구 — 데이터 저장 방식이 정해지면 사건·차수 값으로 바꿔야 함
        // 이름은 ERD 필드를 따름: Investigation.title, Investigation.createdAt, InvestigationSession.sessionNumber
        static let title = "청암로 77"
        static let createdAt = "오후 13:30"
        static let sessionNumber = "1차 조사"

        static let addMemo = "메모 추가"
        static let addPhoto = "사진추가"
        static let takePhoto = "사진 촬영하기"
        static let importPhoto = "사진 불러오기"
        static let edit = "수정"
        static let export = "내보내기"

        static let floorPlanTab = "도면"
        static let albumTab = "앨범"
        static let memoTab = "메모"
        static let albumPlaceholder = "앨범 자리"
        static let memoPlaceholder = "메모 자리"
    }
}

#Preview {
    NavigationStack {
        CaseMainView(onBack: {}, onEdit: {})
    }
}

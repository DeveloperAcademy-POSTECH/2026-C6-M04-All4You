// 사건 작업 메인 화면. 상단 바와 도면·앨범·메모 탭으로 구성된다

import SwiftUI

/// 도면·앨범·메모를 오가며 사건을 작업하는 화면
struct CaseMainView: View {
    // 뒤로가기, 편집하기(펜 아이콘), 사진추가
    let onBack: () -> Void
    let onEdit: () -> Void
    let onAddPhoto: () -> Void

    // 탭을 오가도 고른 값이 남도록 탭이 아니라 이 화면이 기억한다
    @State private var photoFilter = PhotoFilter()
    @State private var dimension: FloorPlanTabView.Dimension = .twoD

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
    /// 사건 제목과 부제를 두 줄로 보여 준다
    private var caseTitle: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            VStack(alignment: .leading) {
                Text(Copy.caseTitle)
                    .font(.headline)
                Text(Copy.caseSubtitle)
                    .font(.subheadline)
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
                    Text(Copy.session)
                    Image(systemName: "chevron.down")
                }
                .font(.subheadline)
            }
        }
    }
    
    // 우측 기능도구들
    private var actionButtons: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            // 메모 작성
            Button(Copy.addMemo, systemImage: "plus.bubble") {
                // TODO: 메모 추가
            }
            // 사진 추가
            Button(Copy.addPhoto, systemImage: "photo.badge.plus", action: onAddPhoto)
            // 도면 수정
            Button(Copy.edit, systemImage: "pencil", action: onEdit)
            // Export
            Button(Copy.export, systemImage: "square.and.arrow.up") {
                // TODO: 내보내기
            }
        }
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
    }
}

// 문구
extension CaseMainView {
    private enum Copy {
        // TEMP: 사건 데이터가 생기기 전 임시 문구 — 데이터 저장 방식이 정해지면 사건·차수 값으로 바꿔야 함
        static let caseTitle = "청암로 77"
        static let caseSubtitle = "오후 13:30"
        static let session = "1차 조사"

        static let addMemo = "메모 추가"
        static let addPhoto = "사진추가"
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
        CaseMainView(onBack: {}, onEdit: {}, onAddPhoto: {})
    }
}

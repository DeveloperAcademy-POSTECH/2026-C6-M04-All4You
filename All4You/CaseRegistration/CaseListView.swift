//
//  CaseListView.swift
//  All4You
//
//  Created by SIA on 11/2/26.
//

// 사건 목록 첫 화면. 아이패드 메모, 파일 앱처럼 왼쪽 사이드바와 오른쪽 목록으로 나뉜다

import SwiftUI

struct CaseListView: View {
    @Environment(CaseStore.self) private var store

    @State private var filter: CaseFilter = .recent
    @State private var selectedCaseID: FireCase.ID?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var searchText = ""
    @State private var isPresentingRegistration = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } detail: {
            NavigationStack {
                CaseListContent(
                    filter: filter,
                    searchText: searchText,
                    selectedCaseID: $selectedCaseID,
                    onRegister: presentRegistration
                )
                .toolbar { detailToolbar }
//                .searchable(text: $searchText, prompt: Copy.searchPrompt)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: filter) {
            selectedCaseID = nil
        }
        .onChange(of: selectedCaseID) { _, id in
            guard let id else { return }
            store.markViewed(id)
            // 사건을 고르면 사이드바를 접고 목록 옆에 미리보기를 띄운다
            withAnimation {
                columnVisibility = .detailOnly
            }
        }
        .sheet(isPresented: $isPresentingRegistration) {
            CaseRegistrationView { newCase in
                store.add(newCase)
                isPresentingRegistration = false
                filter = .inProgress
                // TODO: 평면도 생성 화면이 생기면 등록 직후 그쪽으로 이동하도록 연결
            }
            .presentationDragIndicator(.visible)
        }
    }

    private func presentRegistration() {
        isPresentingRegistration = true
    }
}

// 사이드바
extension CaseListView {
    private var sidebar: some View {
        List(selection: filterSelection) {
            logo
                .listRowBackground(Color.clear)
                .selectionDisabled()

            Section(Copy.caseList) {
                ForEach(CaseFilter.allCases, id: \.self) { item in
                    sidebarRow(item)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(Copy.edit) {
                    // TODO: 사건 편집(삭제·이동)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(Copy.newFolder, systemImage: "folder.badge.plus") {
                    // TODO: 폴더 추가
                }
            }
        }
    }

    private var logo: some View {
        HStack(spacing: Layout.logoSpacing) {
            Image(systemName: "flame.fill")
                // TEMP: 팀 공용 색이 정해지면 바꿔야 함
                .foregroundStyle(.orange)
            Text(Copy.appName)
                .font(.title2.weight(.black))
                .fontWidth(.expanded)
        }
        .font(.title2)
        .accessibilityElement(children: .combine)
    }

    private func sidebarRow(_ item: CaseFilter) -> some View {
        HStack(spacing: Layout.sidebarIconSpacing) {
            Image(systemName: item.systemImage)
                // Figma: SF Pro Regular 17, 34×44 칸 가운데
                .font(.body)
                .frame(width: Layout.sidebarIconWidth)
            Text(item.title)
                // Figma: Subheadline/Emphasized 15/20
                .font(AppTypography.subheadline.weight(.semibold))
        }
        .foregroundStyle(.primary)
        // 숫자 badge는 0이면 숨겨지므로 0도 보이도록 Text로 넘긴다
        .badge(count(for: item).map { Text("\($0)") })
        .tag(item)
    }

    /// 최근 열람은 개수를 보여 주지 않는다
    private func count(for item: CaseFilter) -> Int? {
        switch item {
        case .recent: nil
        case .inProgress: store.count(of: .inProgress)
        case .closed: store.count(of: .closed)
        }
    }

    /// 사이드바 List는 선택값이 옵셔널이어야 해서 감싼다
    private var filterSelection: Binding<CaseFilter?> {
        Binding(
            get: { filter },
            set: { if let newValue = $0 { filter = newValue } }
        )
    }
}

// 목록 상단 바
extension CaseListView {
    @ToolbarContentBuilder
    private var detailToolbar: some ToolbarContent {
        // 사이드바를 접었을 때는 가운데에서 분류를 고른다
        if columnVisibility == .detailOnly {
            ToolbarItem(placement: .principal) {
                Picker(Copy.caseList, selection: $filter) {
                    ForEach(CaseFilter.allCases, id: \.self) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Button(Copy.newCase, systemImage: "square.and.pencil", action: presentRegistration)
        }
        ToolbarItem(placement: .primaryAction) {
            searchField
        }
        // 검색창이 자체 유리 배경을 가지므로 상단 바 배경을 겹치지 않게 한다
        .sharedBackgroundVisibility(.hidden)
    }
    
    /// Figma 글자 크기를 맞추기 위해 시스템 검색창 대신 직접 만든 검색창
    private var searchField: some View {
        HStack(spacing: Layout.searchItemSpacing) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary)

            TextField(
                Copy.searchPrompt,
                text: $searchText,
                // Figma: Subheadline/Regular 15/20, Labels - Vibrant - Controls/Tertiary
                // 유리 배경 위에서 .tertiary는 거의 투명해져서 시스템 tertiaryLabel 색을 직접 쓴다
                prompt: Text(Copy.searchPrompt)
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
            )
            .font(.subheadline)
            .submitLabel(.search)
            // 상단 바가 폭을 줄여도 입력칸이 먼저 자리를 차지하게 한다
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            if searchText.isEmpty {
                Button(Copy.dictation, systemImage: "mic") {
                    // TODO: 음성 받아쓰기 연결
                }
                .labelStyle(.iconOnly)
                // Figma: SF Pro Medium 17, Labels - Vibrant - Controls/Secondary
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary)
                .buttonStyle(.plain)
            } else {
                Button(Copy.clearSearch, systemImage: "xmark.circle.fill") {
                    searchText = ""
                }
                .labelStyle(.iconOnly)
                .foregroundStyle(.tertiary)
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Layout.searchHorizontalPadding)
        .frame(width: Layout.searchWidth, height: Layout.searchHeight)
        .glassEffect(in: .capsule)
    }
}

// 크기
extension CaseListView {
    private enum Layout {
        static let logoSpacing: CGFloat = 8
        static let sidebarIconWidth: CGFloat = 34
        static let sidebarIconSpacing: CGFloat = 6
        // TEMP: Figma에서 검색창 크기 확인 후 맞춰야 함
        static let searchWidth: CGFloat = 220
        static let searchHeight: CGFloat = 44
        static let searchHorizontalPadding: CGFloat = 12
        static let searchItemSpacing: CGFloat = 6
    }
}

// 문구
extension CaseListView {
    private enum Copy {
        static let appName = "FIRELINE"
        static let caseList = "사건 목록"
        static let edit = "편집"
        static let newFolder = "새로운 폴더"
        static let newCase = "새로운 사건"
        static let searchPrompt = "제목, 사건명"
        static let dictation = "받아쓰기"
        static let clearSearch = "검색어 지우기"
    }
}

#Preview("사건 없음") {
    CaseListView()
        .environment(CaseStore())
}

#Preview("사건 있음") {
    CaseListView()
        .environment(CaseStore(cases: FireCase.samples))
}


#Preview {
    CaseListView()
}

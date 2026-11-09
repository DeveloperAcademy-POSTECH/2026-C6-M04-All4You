//
//  CaseListView.swift
//  All4You
//
//  Created by SIA on 11/2/26.
//
//  FIRELINE 사건 목록 화면
//  iPadOS 사이드바 / 상단 탭 바 전환 지원
//

import SwiftUI
import SwiftData

struct CaseListView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Query private var allCases: [FireCase]
    @Query(sort: \CaseFolder.sortOrder) private var folders: [CaseFolder]
    
    @State private var showsSaveError = false
    @State private var saveErrorMessage = ""
    
    /// 사이드바(또는 사이드바를 접었을 때 위쪽 탭 막대)에서 고른 목록
    @State private var selection: CaseListSelection? = .filter(.recent)
    @State private var selectedCaseID: FireCase.ID?
    @State private var searchText = ""
    @State private var isPresentingRegistration = false
    
    /// 방금 등록해 등록 시트가 닫히면 열 사건
    @State private var pendingFloorPlan: FireCase?
    /// 지금 열어 전체 화면으로 보여 주는 사건
    @State private var openedCase: FireCase?
    /// 사건을 열 때 평면도가 이미 있었는지. 있었으면 메인부터, 열고 나서 막 만들었으면 2D 수정부터 보여 준다
    @State private var openedWithFloorPlan = false
    
    /// 사이드바를 펼쳤는지(.all) 접었는지(.detailOnly)
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    /// 편집 중이면 기본 목록은 흐려지고, 사용자 목록에 ⋯ 메뉴와 순서 바꾸기 손잡이가 보인다
    @State private var editMode: EditMode = .inactive
    
    /// 새 목록 만들기·이름 바꾸기 알림의 입력값
    @State private var folderNameInput = ""
    @State private var isCreatingFolder = false
    /// 이름을 바꾸는 중인 목록. 값이 있으면 이름 변경 알림이 뜬다
    @State private var renamingFolder: CaseFolder?
    /// 삭제를 확인하는 중인 목록. 값이 있으면 삭제 확인 알림이 뜬다
    @State private var deletingFolder: CaseFolder?
    
    var body: some View {
        
        // 사이드바 편집(⋯ 메뉴, 순서 바꾸기)은 TabView 사이드바로 만들 수 없어 List 사이드바를 쓰고,
        // 사이드바를 접으면 위쪽 탭 막대를 직접 띄운다
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } detail: {
            detail
        }
        
        .tint(.black)
        
        .onChange(of: selection) {
            selectedCaseID = nil
        }
        
        // 새 목록 만들기
        .alert(Copy.newFolderTitle, isPresented: $isCreatingFolder) {
            TextField(Copy.folderNamePlaceholder, text: $folderNameInput)
            Button(Copy.cancel, role: .cancel) {}
            Button(Copy.save, action: createFolder)
        }
        
        // 목록 이름 변경
        .alert(Copy.renameFolderTitle, isPresented: isRenameAlertShown) {
            TextField(Copy.folderNamePlaceholder, text: $folderNameInput)
            Button(Copy.cancel, role: .cancel) {}
            Button(Copy.save, action: renameFolder)
        }
        
        // 목록 삭제 확인
        .alert(
            Copy.deleteFolderTitle(deletingFolder?.name ?? ""),
            isPresented: isDeleteAlertShown
        ) {
            Button(Copy.cancel, role: .cancel) {}
            Button(Copy.delete, role: .destructive, action: deleteFolder)
        } message: {
            Text(Copy.deleteFolderMessage)
        }
        
        .sheet(
            isPresented: $isPresentingRegistration,
            onDismiss: {
                // 사건 등록 시트가 닫힌 후 전체 화면 표시
                if let pendingFloorPlan {
                    open(pendingFloorPlan)
                    self.pendingFloorPlan = nil
                }
            }
        ) {
            CaseRegistrationView { newCase in
                // 새 사건은 1차 조사부터 시작한다
                newCase.addSession()
                modelContext.insert(newCase)
                
                do {
                    // 1. SwiftData에 사건 저장
                    try modelContext.save()
                    
                    // 2. 다음 화면에 전달할 사건 보관
                    pendingFloorPlan = newCase
                    
                    // 3. 조사 중 목록으로 이동
                    selection = .filter(.inProgress)
                    
                    // 4. 사건 등록 시트 닫기
                    isPresentingRegistration = false
                    
                } catch {
                    modelContext.delete(newCase)
                    
                    saveErrorMessage = "사건 저장 실패: \(error.localizedDescription)"
                    showsSaveError = true
                }
            }
            .presentationDragIndicator(.visible)
            .alert("저장 실패", isPresented: $showsSaveError) {
                Button("확인", role: .cancel) { }
            } message: {
                Text(saveErrorMessage)
            }
        }
        // 평면도가 있으면 사건 작업 화면, 없으면 평면도를 만드는 화면을 띄운다
        .fullScreenCover(item: $openedCase) { fireCase in
            if fireCase.floorPlan != nil {
                CaseFlowView(fireCase: fireCase, startsAtMain: openedWithFloorPlan, onClose: { openedCase = nil })
            } else {
                NavigationStack {
                    FloorPlanMethodSelectionView(
                        fireCase: fireCase
                    )
                }
            }
        }
        
    }
    
    private func presentRegistration() {
        isPresentingRegistration = true
    }
    
    /// 사건을 연 시각을 남기고 사건 화면을 띄운다
    private func open(_ fireCase: FireCase) {
        fireCase.lastViewedAt = .now
        openedWithFloorPlan = fireCase.floorPlan != nil
        openedCase = fireCase
    }
}

// MARK: - 사이드바

extension CaseListView {
    
    private var isEditing: Bool {
        editMode.isEditing
    }
    
    /// 로고, 최근 열람, "사건 목록" 아래 조사 중·조사 종결·사용자 목록
    private var sidebar: some View {
        List(selection: $selection) {
            
            // FIRELINE 벡터 로고
            HStack(spacing: 8) {
                Image("FirelineFlame")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 24)
                    .offset(x: -6)
                
                Image("FirelineWordmark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 131, height: 24)
                    .offset(x: -6)
            }
            .padding(.vertical, 12)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            
            defaultRow(.recent)
            
            // "사건 목록"은 고정 제목 (접거나 펼 수 없다)
            Section {
                defaultRow(.inProgress)
                defaultRow(.closed)
                
                ForEach(folders) { folder in
                    folderRow(folder)
                }
                .onMove(perform: moveFolders)
                
            } header: {
                Text(Copy.caseList)
            }
        }
        .listStyle(.sidebar)
        .environment(\.editMode, $editMode)
        
        // 시스템 사이드바 버튼 대신 Figma처럼 오른쪽 위에 직접 둔다
        .toolbar(removing: .sidebarToggle)
        .toolbar {
            sidebarToolbar
        }
    }
    
    /// 최근 열람·조사 중·조사 종결. 바꿀 수 없는 기본 목록이라 편집 중에는 흐리게 보이고 고를 수 없다
    private func defaultRow(_ filter: CaseFilter) -> some View {
        Label(filter.title, systemImage: filter.systemImage)
        // 최근 열람은 개수를 보이지 않고, 편집 중에는 개수를 숨긴다
            .badge(filter == .recent || isEditing ? nil : Text("\(caseCount(of: filter))"))
            .opacity(isEditing && filter != .recent ? Layout.dimmedOpacity : 1)
            .selectionDisabled(isEditing)
            .tag(CaseListSelection.filter(filter))
    }
    
    /// 사용자가 만든 목록. 편집 중에는 개수 대신 ⋯ 메뉴(이름 변경·삭제)가 보이고, 손잡이를 끌어 순서를 바꾼다
    private func folderRow(_ folder: CaseFolder) -> some View {
        HStack {
            Label(folder.name, systemImage: "folder")
            if isEditing {
                Spacer()
                Menu {
                    folderActions(folder)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.primary)
                }
                .accessibilityLabel(Copy.folderMenu(folder.name))
            }
        }
        .badge(isEditing ? nil : Text("\(folder.cases.count)"))
        .tag(CaseListSelection.folder(folder.id))
    }
    
    /// 목록 이름 변경·목록 삭제
    @ViewBuilder
    private func folderActions(_ folder: CaseFolder) -> some View {
        Button(Copy.renameFolder, systemImage: "pencil") {
            folderNameInput = folder.name
            renamingFolder = folder
        }
        
        Button(role: .destructive) {
            deletingFolder = folder
        } label: {
            Label {
                Text(Copy.deleteFolder)
            } icon: {
                // Menu는 아이콘을 template으로 그려 tint(.black)를 따라가므로 원본 색 이미지로 넘긴다
                Image(uiImage: Self.destructiveTrashImage)
            }
        }
    }
    
    /// 메뉴 안에서도 빨간색이 유지되는 쓰레기통 아이콘
    private static let destructiveTrashImage: UIImage = {
        let image = UIImage(systemName: "trash") ?? UIImage()
        return image.withTintColor(.systemRed, renderingMode: .alwaysOriginal)
    }()
    
    /// 왼쪽: 편집(편집 중에는 완료 체크), 오른쪽: 새 목록 만들기·사이드바 접기
    @ToolbarContentBuilder
    private var sidebarToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if isEditing {
                Button(Copy.done, systemImage: "checkmark") {
                    withAnimation {
                        editMode = .inactive
                    }
                }
            } else {
                Button(Copy.edit) {
                    withAnimation {
                        editMode = .active
                    }
                }
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button(Copy.newFolder, systemImage: "folder.badge.plus") {
                folderNameInput = ""
                isCreatingFolder = true
            }
        }
        ToolbarSpacer(.fixed, placement: .topBarTrailing)
        ToolbarItem(placement: .topBarTrailing) {
            Button(Copy.hideSidebar, systemImage: "sidebar.left") {
                withAnimation {
                    editMode = .inactive
                    columnVisibility = .detailOnly
                }
            }
        }
    }
    
    /// 사용자 목록에 들어 있지 않은 사건만 상태별로 센다 (사건은 목록 하나에만 들어간다)
    private func caseCount(of filter: CaseFilter) -> Int {
        switch filter {
        case .recent:
            allCases.count
        case .inProgress:
            allCases.filter { $0.folder == nil && $0.status == .inProgress }.count
        case .closed:
            allCases.filter { $0.folder == nil && $0.status == .closed }.count
        }
    }
}

// MARK: - 사건 목록

extension CaseListView {
    
    private var isSidebarHidden: Bool {
        columnVisibility != .all
    }
    /// 오른쪽 사건 목록. 고른 목록의 사건을 보여 준다
    private var detail: some View {
        let current = selection ?? .filter(.recent)
        return NavigationStack {
            CaseListContent(
                selection: current,
                title: title(of: current),
                searchText: searchText,
                selectedCaseID: $selectedCaseID,
                onRegister: presentRegistration,
                onOpen: open
            )
            .toolbar {
                if isSidebarHidden {
                    ToolbarItem(placement: .principal) {
                        collapsedTabBar
                    }
                    .sharedBackgroundVisibility(.hidden)
                }
                detailToolbar
            }
            .searchable(
                text: $searchText,
                placement: .toolbar,
                prompt: "제목, 사건명"
            )
        }
    }
    
    /// 사이드바를 접었을 때 위에 뜨는 탭 막대. 사이드바 펼치기 버튼과 기본 목록 세 개
    private var collapsedTabBar: some View {
        HStack(spacing: Layout.tabSpacing) {
            Button(Copy.showSidebar, systemImage: "sidebar.left") {
                withAnimation {
                    columnVisibility = .all
                }
            }
            .labelStyle(.iconOnly)
            .padding(.horizontal, Layout.tabHorizontalPadding)
            
            ForEach(CaseFilter.allCases, id: \.self) { filter in
                let isSelected = selection == .filter(filter)
                Button(filter.title) {
                    selection = .filter(filter)
                }
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, Layout.tabHorizontalPadding)
                .padding(.vertical, Layout.tabVerticalPadding)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(Color(uiColor: .systemGray5))
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .font(.subheadline)
        .padding(Layout.tabBarPadding)
        .glassEffect(in: .capsule)
    }
    
    private func title(of selection: CaseListSelection) -> String {
        switch selection {
        case .filter(let filter):
            filter.title
        case .folder(let id):
            folders.first { $0.id == id }?.name ?? ""
        }
    }
}

// MARK: - 목록 만들기·바꾸기·지우기

extension CaseListView {
    
    private var trimmedFolderName: String {
        folderNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// 맨 아래에 새 목록을 만들고 바로 고른다. 이름이 비어 있으면 만들지 않는다
    private func createFolder() {
        guard !trimmedFolderName.isEmpty else { return }
        let folder = CaseFolder(name: trimmedFolderName, sortOrder: (folders.last?.sortOrder ?? -1) + 1)
        modelContext.insert(folder)
        saveFolders()
        selection = .folder(folder.id)
    }
    
    /// 이름이 비어 있으면 바꾸지 않는다
    private func renameFolder() {
        defer { renamingFolder = nil }
        guard let renamingFolder, !trimmedFolderName.isEmpty else { return }
        renamingFolder.name = trimmedFolderName
        saveFolders()
    }
    
    /// 목록만 지운다. 들어 있던 사건은 목록에서 빠져 상태에 따라 조사 중·조사 종결에 다시 보인다
    private func deleteFolder() {
        defer { deletingFolder = nil }
        guard let deletingFolder else { return }
        if selection == .folder(deletingFolder.id) {
            selection = .filter(.inProgress)
        }
        modelContext.delete(deletingFolder)
        saveFolders()
    }
    
    /// 끌어서 바꾼 순서대로 sortOrder를 다시 매긴다
    private func moveFolders(from source: IndexSet, to destination: Int) {
        var reordered = folders
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, folder) in reordered.enumerated() {
            folder.sortOrder = index
        }
        saveFolders()
    }
    
    private func saveFolders() {
        do {
            try modelContext.save()
        } catch {
            saveErrorMessage = "목록 저장 실패: \(error.localizedDescription)"
            showsSaveError = true
        }
    }
    
    private var isRenameAlertShown: Binding<Bool> {
        Binding(
            get: { renamingFolder != nil },
            set: { if !$0 { renamingFolder = nil } }
        )
    }
    
    private var isDeleteAlertShown: Binding<Bool> {
        Binding(
            get: { deletingFolder != nil },
            set: { if !$0 { deletingFolder = nil } }
        )
    }
}

// MARK: - 사이드바 헤더

extension CaseListView {
    
    private var logo: some View {
        Image("logo")
            .resizable()
            .scaledToFit()
            .frame(
                width: 169,
                height: 24,
                alignment: .leading
            )
            .clipped()
            .accessibilityLabel("FIRELINE")
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
    }
}

// MARK: - 목록 상단 툴바

extension CaseListView {
    
    @ToolbarContentBuilder
    private var detailToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button(
                Copy.newCase,
                systemImage: "square.and.pencil",
                action: presentRegistration
            )
        }
    }
    
    
    /// Figma 기준 커스텀 검색창
    private var searchField: some View {
        
        HStack(spacing: Layout.searchItemSpacing) {
            
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary)
            
            TextField(
                Copy.searchPrompt,
                text: $searchText,
                prompt: Text(Copy.searchPrompt)
                    .foregroundStyle(
                        Color(uiColor: .tertiaryLabel)
                    )
            )
            .font(.subheadline)
            .submitLabel(.search)
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .layoutPriority(1)
            
            if searchText.isEmpty {
                
                Button(
                    Copy.dictation,
                    systemImage: "mic"
                ) {
                    // TODO: 음성 받아쓰기 연결
                }
                .labelStyle(.iconOnly)
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary)
                .buttonStyle(.plain)
                
            } else {
                
                Button(
                    Copy.clearSearch,
                    systemImage: "xmark.circle.fill"
                ) {
                    searchText = ""
                }
                .labelStyle(.iconOnly)
                .foregroundStyle(.tertiary)
                .buttonStyle(.plain)
            }
        }
        .padding(
            .horizontal,
            Layout.searchHorizontalPadding
        )
        .frame(
            width: Layout.searchWidth,
            height: Layout.searchHeight
        )
        .glassEffect(in: .capsule)
        .fixedSize()
    }
}

// MARK: - Layout

extension CaseListView {
    
    private enum Layout {
        
        static let logoSpacing: CGFloat = 8
        
        static let searchWidth: CGFloat = 220
        static let searchHeight: CGFloat = 44
        
        static let searchHorizontalPadding: CGFloat = 12
        static let searchItemSpacing: CGFloat = 6
        
        /// 편집 중 기본 목록(조사 중·조사 종결)을 흐리게 보이는 정도
        static let dimmedOpacity: CGFloat = 0.4
        
        // 사이드바를 접었을 때 위쪽 탭 막대
        static let tabSpacing: CGFloat = 4
        static let tabHorizontalPadding: CGFloat = 12
        static let tabVerticalPadding: CGFloat = 8
        static let tabBarPadding: CGFloat = 4
    }
}

// MARK: - Copy

extension CaseListView {
    
    private enum Copy {
        
        static let appName = "FIRELINE"
        
        static let caseList = "사건 목록"
        
        static let newCase = "새로운 사건"
        
        static let searchPrompt = "제목, 사건명"
        
        static let dictation = "받아쓰기"
        
        static let clearSearch = "검색어 지우기"
        
        // 사이드바
        static let edit = "편집"
        static let done = "완료"
        static let hideSidebar = "사이드바 접기"
        static let showSidebar = "사이드바 펼치기"
        static let newFolder = "새로운 목록"
        static let renameFolder = "목록 이름 변경"
        static let deleteFolder = "목록 삭제"
        static let cancel = "취소"
        static let save = "저장"
        static let delete = "삭제"
        // TEMP: Figma에 새 목록 만들기 알림이 없어 이름 변경 알림과 같은 형식으로 작성 — 팀 확인 필요
        static let newFolderTitle = "새로운 목록"
        static let renameFolderTitle = "목록 이름 변경"
        static let folderNamePlaceholder = "목록 이름"
        static let deleteFolderMessage = "목록을 삭제해도 포함된 사건은 삭제되지 않아요"
        
        static func deleteFolderTitle(_ name: String) -> String {
            "'\(name)' 목록을 삭제할까요?"
        }
        
        static func folderMenu(_ name: String) -> String {
            "\(name) 목록 편집"
        }
    }
}

// MARK: - Preview (실제 기기 DB와 분리된 빈 저장소)

#Preview("사건 없음") {
    CaseListView()
        .modelContainer(for: FireCase.self, inMemory: true)
}

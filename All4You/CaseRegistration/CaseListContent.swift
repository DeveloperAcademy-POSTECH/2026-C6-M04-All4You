//
//  CaseListContent.swift
//  All4You
//
//  Created by SIA on 11/4/26.
//

// 사건 목록 오른쪽 영역. 빈 화면, 사건 목록, 고른 사건의 미리보기를 보여 준다

import SwiftUI
import SwiftData

struct CaseListContent: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allCases: [FireCase]
    @Query(sort: \CaseFolder.sortOrder) private var folders: [CaseFolder]
    
    /// 사이드바에서 고른 목록
    let selection: CaseListSelection
    /// 상단 제목 (기본 목록 이름 또는 사용자 목록 이름)
    let title: String
    let searchText: String
    @Binding var selectedCaseID: FireCase.ID?
    /// 사건 목록과 미리보기 사이의 사용자 지정 폭
    @State private var listWidthFraction: CGFloat = 0.55
    @State private var dragStartListWidth: CGFloat?
    @State private var splitDragOffset: CGFloat = 0
    /// 길게 눌러 "사건 삭제"를 고른 사건. 값이 있으면 확인 창이 뜬다
    @State private var deletingCase: FireCase?
    /// 이름을 변경할 사건과 입력 중인 이름
    @State private var renamingCase: FireCase?
    @State private var caseNameInput = ""
    let onRegister: () -> Void
    /// 미리보기의 "사건 열기"를 누르면 그 사건을 연다
    let onOpen: (FireCase, CaseStartTab) -> Void
    
    private var cases: [FireCase] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        // 주소뿐 아니라 사건명·상세 주소로도 찾는다
        let searched = keyword.isEmpty
        ? allCases
        : allCases.filter {
            $0.address.localizedStandardContains(keyword)
            || $0.caseName.localizedStandardContains(keyword)
            || $0.detailAddress.localizedStandardContains(keyword)
        }
        
        // 사건은 목록 하나에만 들어가므로, 조사 중·조사 종결에는 사용자 목록에 넣지 않은 사건만 보인다
        switch selection {
        case .filter(.recent):
            return searched.sorted { $0.lastViewedAt > $1.lastViewedAt }
        case .filter(.inProgress):
            return searched.filter { $0.folder == nil && $0.status == .inProgress }
                .sorted { $0.occurredAt > $1.occurredAt }
        case .filter(.closed):
            return searched.filter { $0.folder == nil && $0.status == .closed }
                .sorted { $0.occurredAt > $1.occurredAt }
        case .folder(let folderID):
            return searched.filter { $0.folder?.id == folderID }
                .sorted { $0.occurredAt > $1.occurredAt }
        }
    }
    
    private var selectedCase: FireCase? {
        allCases.first { $0.id == selectedCaseID }
    }
    
    /// 전체 사건이 존재하지만 현재 선택한 목록만 비어 있을 때 표시할 문구.
    /// 전체 사건이 0개인 경우에는 기존 emptyView의 "등록된 사건이 없어요"를 유지한다.
    private var emptyListTitle: String {
        switch selection {
        case .filter(.recent):
            return "최근 열람한 사건이 없어요"
        case .filter(.inProgress):
            return "조사 중인 사건이 없어요"
        case .filter(.closed):
            return "종결된 사건이 없어요"
        case .folder:
            return "해당 사건이 없어요"
        }
    }
    
    private var emptyListDescription: String {
        switch selection {
        case .filter(.recent):
            return "열람한 사건은 이곳에서 확인할 수 있어요"
        case .filter(.inProgress):
            return "조사를 시작한 사건은 이곳에서 확인할 수 있어요"
        case .filter(.closed):
            return "조사가 끝난 사건은 이곳에서 확인할 수 있어요"
        case .folder:
            return "다른 목록을 선택하거나 새로운 사건을 등록해 주세요"
        }
    }
    
    var body: some View {
        Group {
            if allCases.isEmpty {
                emptyView
            } else if cases.isEmpty && !searchText.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else if cases.isEmpty {
                ContentUnavailableView(
                    emptyListTitle,
                    systemImage: "folder",
                    description: Text(emptyListDescription)
                )
            } else {
                Group {
                    if let selectedCase {
                        GeometryReader { geometry in
                            let availableWidth = max(0, geometry.size.width - Layout.dividerWidth)
                            let listWidth = boundedListWidth(availableWidth: availableWidth)
                            let previewWidth = max(0, availableWidth - listWidth)
                            
                            ZStack(alignment: .topLeading) {
                                caseList
                                    .frame(width: listWidth, height: geometry.size.height)
                                    .clipped()
                                
                                CasePreviewView(fireCase: selectedCase, onOpen: { onOpen(selectedCase, $0) })
                                    .frame(width: previewWidth, height: geometry.size.height)
                                    .offset(x: listWidth + Layout.dividerWidth)
                                
                                resizeDivider(availableWidth: availableWidth, currentWidth: listWidth)
                                    .frame(height: geometry.size.height)
                                    .offset(x: listWidth)
                            }
                            // 움직이지 않는 부모 좌표계를 기준으로 구분선 드래그 계산
                            .coordinateSpace(name: "caseSplitArea")
                            .overlay(alignment: .topLeading) {
                                Rectangle()
                                    .fill(Color(uiColor: .separator))
                                    .frame(width: 1, height: geometry.size.height + 140)
                                    .offset(x: listWidth + Layout.dividerWidth / 2 - 0.5, y: -140)
                                    .allowsHitTesting(false)
                            }
                            .transaction {
                                if dragStartListWidth != nil { $0.animation = nil }
                            }
                        }
                    } else {
                        caseList
                    }
                }
            }
        }
        .navigationTitle(allCases.isEmpty ? "" : title)
        .navigationBarTitleDisplayMode(allCases.isEmpty ? .inline : .large)
        .alert(Copy.renameCase, isPresented: Binding(
            get: { renamingCase != nil },
            set: { if !$0 { renamingCase = nil } }
        )) {
            TextField(Copy.caseNamePlaceholder, text: $caseNameInput)
            
            Button(Copy.cancel, role: .cancel) {
                renamingCase = nil
            }
            Button(Copy.save) {
                renameCase()
            }
            .disabled(caseNameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text(Copy.renameCaseDescription)
        }
        .alert(
            Copy.deleteTitle(deletingCase?.title ?? ""),
            isPresented: Binding(get: { deletingCase != nil }, set: { if !$0 { deletingCase = nil } }),
            presenting: deletingCase
        ) { fireCase in
            Button(Copy.delete, role: .destructive) {
                delete(fireCase)
            }
            Button(Copy.cancel, role: .cancel) {}
        } message: { _ in
            Text(Copy.deleteMessage)
        }
    }
}

// 서브 뷰
extension CaseListContent {
    private var emptyView: some View {
        VStack(spacing: 0) {
            Image(systemName: "folder")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .padding(.bottom, Layout.emptyIconSpacing)
            
            Text(Copy.emptyTitle)
                .font(AppTypography.title1Emphasized)
            
            Text(Copy.emptyDescription)
                .font(AppTypography.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, Layout.emptyDescriptionSpacing)
            
            Button(action: onRegister) {
                Text(Copy.register)
                // 버튼 전체 폭을 바깥 frame에 맞추기 위해 글자 영역을 꽉 채운다
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            // Figma Size: Large
            .controlSize(.large)
            // 유리 버튼 여백까지 포함한 전체 폭
            .frame(width: Layout.registerButtonWidth)
            .tint(.black)
            // Figma 기준 설명 글과 버튼 사이 간격
            .padding(.top, Layout.emptyButtonSpacing)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.container, edges: .top)
    }
    
    /// 현재 선택한 사건명이 두 줄 이내로 표시되도록 미리보기 최소 폭을 계산한다.
    /// 드래그 좌표계(caseSplitArea)와 이동량 처리 방식은 변경하지 않는다.
    private func splitWidthLimits(availableWidth: CGFloat) -> (minList: CGFloat, maxList: CGFloat) {
        // 왼쪽 사건 목록은 390pt를 확보한다. 화면이 더 좁을 때만 예외적으로 축소한다.
        let minList = min(Layout.minimumListWidth, max(0, availableWidth - Layout.minimumPreviewWidth))
        let titleWidth = selectedCase.map { CasePreviewView.minimumWidthForTwoLineTitle($0.title) }
        ?? Layout.minimumPreviewWidth
        let requiredPreview = max(Layout.minimumPreviewWidth, titleWidth)
        // 제목이 길더라도 왼쪽 최소 폭이 우선이다. 양쪽 조건을 모두
        // 충족할 수 없는 화면 크기에서는 오른쪽에 가능한 공간을 남긴다.
        let maxList = max(minList, availableWidth - requiredPreview)
        return (minList, maxList)
    }
    
    /// 메모처럼 드래그 도중 화면에 이동량을 반영하고 손을 떼면 비율을 저장한다.
    private func boundedListWidth(availableWidth: CGFloat) -> CGFloat {
        let limits = splitWidthLimits(availableWidth: availableWidth)
        let proposed = (dragStartListWidth ?? availableWidth * listWidthFraction) + splitDragOffset
        return min(max(proposed, limits.minList), limits.maxList)
    }
    
    private func resizeDivider(availableWidth: CGFloat, currentWidth: CGFloat) -> some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: Layout.dividerWidth)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .named("caseSplitArea"))
                    .onChanged { value in
                        if dragStartListWidth == nil {
                            dragStartListWidth = currentWidth
                        }
                        splitDragOffset = value.translation.width
                    }
                    .onEnded { value in
                        if availableWidth > 0 {
                            let limits = splitWidthLimits(availableWidth: availableWidth)
                            let proposed = (dragStartListWidth ?? currentWidth) + value.translation.width
                            let finalWidth = min(max(proposed, limits.minList), limits.maxList)
                            listWidthFraction = finalWidth / availableWidth
                        }
                        dragStartListWidth = nil
                        splitDragOffset = 0
                    }
            )
            .accessibilityLabel("사건 목록 너비 조절")
    }
    
    @ViewBuilder
    private var caseList: some View {
        // List 기본 selection 색을 쓰지 않고 직접 회색 선택 배경을 그린다.
        List {
            if selection == .filter(.recent) {
                ForEach(cases) { caseRow($0) }
            } else {
                ForEach(MonthSection.group(cases)) { section in
                    Section {
                        ForEach(section.cases) { caseRow($0) }
                    } header: {
                        Text(monthTitle(section.month))
                            .font(.title3.bold())
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        .listStyle(.plain)
    }
    
    private func caseRow(_ fireCase: FireCase) -> some View {
        Button {
            selectedCaseID = fireCase.id
        } label: {
            HStack {
                Text(fireCase.title)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 8)
                Text(Self.dateFormatter.string(from: fireCase.occurredAt))
                    .font(AppTypography.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .foregroundStyle(.primary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.12)
                .onEnded { _ in
                    selectedCaseID = fireCase.id
                }
        )
        .listRowBackground(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    selectedCaseID == fireCase.id
                    ? Color.gray200
                    : Color.clear
                )
                .padding(.leading, 7)
        )
        // 꾸욱 눌렀을 때 모양 및 효과
        .contextMenu {
            Button(Copy.renameCase, systemImage: "pencil") {
                caseNameInput = fireCase.title
                renamingCase = fireCase
            }
            
            moveMenu(fireCase)
            
            Button(role: .destructive) {
                deletingCase = fireCase
            } label: {
                Label {
                    Text(Copy.deleteCase)
                } icon: {
                    Image(uiImage: Self.destructiveTrashImage)
                }
            }
        } preview: {
            Text(fireCase.title)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(minWidth: 220, maxWidth: 400, alignment: .leading)
                .background(
                    Color(uiColor: .secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 12)
                )
        }
        // 드래그해서 폴더에 넣기
        .draggable(fireCase.id.uuidString) {
            Text(fireCase.title)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: 220)
                .background(
                    .regularMaterial,
                    in: RoundedRectangle(cornerRadius: 12)
                )
        }
    }
    
    /// 메뉴 안에서도 빨간색이 유지되는 쓰레기통 아이콘
    private static let destructiveTrashImage: UIImage = {
        let image = UIImage(systemName: "trash") ?? UIImage()
        return image.withTintColor(.systemRed, renderingMode: .alwaysOriginal)
    }()
    
    /// 조사 상태별 기본 목록과 사용자 목록으로 사건을 이동한다.
    @ViewBuilder
    private func moveMenu(_ fireCase: FireCase) -> some View {
        Menu(Copy.moveToFolder, systemImage: "folder") {
            Button {
                move(fireCase, to: .inProgress)
            } label: {
                if fireCase.folder == nil && fireCase.status == .inProgress {
                    Label(CaseFilter.inProgress.title, systemImage: "checkmark")
                } else {
                    Text(CaseFilter.inProgress.title)
                }
            }
            
            Button {
                move(fireCase, to: .closed)
            } label: {
                if fireCase.folder == nil && fireCase.status == .closed {
                    Label(CaseFilter.closed.title, systemImage: "checkmark")
                } else {
                    Text(CaseFilter.closed.title)
                }
            }
            
            if !folders.isEmpty {
                Divider()
                ForEach(folders) { folder in
                    Button {
                        move(fireCase, to: folder)
                    } label: {
                        if fireCase.folder?.id == folder.id {
                            Label(folder.name, systemImage: "checkmark")
                        } else {
                            Text(folder.name)
                        }
                    }
                }
            }
        }
    }
    
    /// 사건명만 수정한다. 주소 등 원래 출동 정보는 변경하지 않는다.
    private func renameCase() {
        guard let renamingCase else { return }
        let newName = caseNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty else { return }
        
        let previousName = renamingCase.caseName
        renamingCase.caseName = newName
        do {
            try modelContext.save()
            self.renamingCase = nil
        } catch {
            renamingCase.caseName = previousName
            self.renamingCase = nil
            // 저장 실패 UI는 기존 프로젝트의 공통 오류 처리에 연결 가능
        }
    }
    
    /// 사건을 지운다. 평면도·조사 차수·사진·메모도 함께 지워진다 (사건 모델의 관계 삭제 규칙)
    private func delete(_ fireCase: FireCase) {
        if selectedCaseID == fireCase.id {
            selectedCaseID = nil
        }
        modelContext.delete(fireCase)
        try? modelContext.save()
    }
    
    /// 사용자 폴더로 이동할 때는 현재 조사 상태를 유지한다.
    private func move(_ fireCase: FireCase, to folder: CaseFolder) {
        let previousFolder = fireCase.folder
        fireCase.folder = folder
        do {
            try modelContext.save()
        } catch {
            fireCase.folder = previousFolder
        }
    }
    
    /// 기본 목록으로 이동할 때는 사용자 폴더를 해제하고 조사 상태를 변경한다.
    private func move(_ fireCase: FireCase, to status: FireCase.Status) {
        let previousFolder = fireCase.folder
        let previousStatus = fireCase.status
        fireCase.folder = nil
        fireCase.status = status
        do {
            try modelContext.save()
        } catch {
            fireCase.folder = previousFolder
            fireCase.status = previousStatus
        }
    }
    
    private func monthTitle(_ month: Date) -> String {
        let calendar = Calendar.current
        let isThisYear = calendar.isDate(
            month,
            equalTo: .now,
            toGranularity: .year
        )
        
        let formatter = isThisYear
        ? Self.currentYearMonthFormatter
        : Self.previousYearMonthFormatter
        
        return formatter.string(from: month)
    }
    
}

// 날짜 형식
extension CaseListContent {
    /// 예) 2026.9.28. 14:36
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.M.d. HH:mm"
        return formatter
    }()
    
    /// 올해: 예) 9월
    private static let currentYearMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M월"
        return formatter
    }()
    
    /// 지난해 등 다른 연도: 예) 2025년 11월
    private static let previousYearMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 M월"
        return formatter
    }()
}

// 크기
extension CaseListContent {
    private enum Layout {
        static let minimumListWidth: CGFloat = 390
        static let minimumPreviewWidth: CGFloat = 280
        static let dividerWidth: CGFloat = 14
        static let registerButtonWidth: CGFloat = 330
        static let emptyIconSpacing: CGFloat = 16
        static let emptyDescriptionSpacing: CGFloat = 4
        static let emptyButtonSpacing: CGFloat = 32
    }
}

// 문구
extension CaseListContent {
    private enum Copy {
        static let emptyTitle = "등록된 사건이 없어요"
        static let emptyDescription = "새로운 사건을 등록하면 이곳에서 확인할 수 있어요"
        static let register = "새로운 사건 등록하기"
        static let renameCase = "사건 이름 변경"
        static let caseNamePlaceholder = "사건 이름"
        static let renameCaseDescription = "변경할 사건 이름을 입력해 주세요"
        static let save = "저장"
        static let moveToFolder = "목록으로 이동"
        static let removeFromFolder = "목록에서 빼기"
        // TEMP: Figma에 사건 삭제 화면이 없어 사이드바 목록 삭제와 같은 형식으로 작성 — 디자인 확인 필요
        static let deleteCase = "사건 삭제"
        static let delete = "삭제"
        static let cancel = "취소"
        static let deleteMessage = "도면·사진·메모가 모두 삭제되고 되돌릴 수 없어요."
        static func deleteTitle(_ name: String) -> String { "'\(name)' 사건을 삭제할까요?" }
    }
}

#Preview("SwiftData 빈 목록") {
    @Previewable @State var selectedCaseID: FireCase.ID?
    
    NavigationStack {
        CaseListContent(
            selection: .filter(.recent),
            title: CaseFilter.recent.title,
            searchText: "",
            selectedCaseID: $selectedCaseID,
            onRegister: {},
            onOpen: { _, _ in }
        )
    }
    .modelContainer(for: FireCase.self, inMemory: true)
}

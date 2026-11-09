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
    @State private var preferredListWidth: CGFloat = 380
    @State private var dragStartListWidth: CGFloat?
    /// 길게 눌러 "사건 삭제"를 고른 사건. 값이 있으면 확인 창이 뜬다
    @State private var deletingCase: FireCase?
    let onRegister: () -> Void
    /// 미리보기의 "사건 열기"를 누르면 그 사건을 연다
    let onOpen: (FireCase) -> Void
    
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
    
    var body: some View {
        Group {
            if allCases.isEmpty {
                emptyView
            } else if cases.isEmpty && !searchText.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else if cases.isEmpty {
                ContentUnavailableView(
                    "해당 사건이 없어요",
                    systemImage: "folder",
                    description: Text("다른 목록을 선택하거나 새로운 사건을 등록해 주세요")
                )
            } else {
                Group {
                    if let selectedCase {
                        GeometryReader { geometry in
                            let listWidth = boundedListWidth(availableWidth: geometry.size.width)
                            HStack(spacing: 0) {
                                caseList
                                    .frame(width: listWidth)
                                
                                // 목록과 미리보기 사이를 손가락/포인터로 드래그하여 너비 변경
                                resizeDivider(availableWidth: geometry.size.width, currentWidth: listWidth)
                                
                                CasePreviewView(fireCase: selectedCase, onOpen: { onOpen(selectedCase) })
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                    } else {
                        caseList
                    }
                }
                .animation(.default, value: selectedCaseID)
            }
        }
        .navigationTitle(allCases.isEmpty ? "" : title)
        .navigationBarTitleDisplayMode(allCases.isEmpty ? .inline : .large)
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
    
    /// 사용 가능한 공간 안에서 미리보기의 최소 폭을 확보한다.
    private func boundedListWidth(availableWidth: CGFloat) -> CGFloat {
        let maximum = max(Layout.minimumListWidth, availableWidth - Layout.dividerWidth - Layout.minimumPreviewWidth)
        return min(max(preferredListWidth, Layout.minimumListWidth), maximum)
    }
    
    private func resizeDivider(availableWidth: CGFloat, currentWidth: CGFloat) -> some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: Layout.dividerWidth)
            .overlay {
                Rectangle()
                    .fill(Color(uiColor: .separator))
                    .frame(width: 1)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        if dragStartListWidth == nil { dragStartListWidth = currentWidth }
                        let candidate = (dragStartListWidth ?? currentWidth) + value.translation.width
                        let maxWidth = max(Layout.minimumListWidth, availableWidth - Layout.dividerWidth - Layout.minimumPreviewWidth)
                        preferredListWidth = min(max(candidate, Layout.minimumListWidth), maxWidth)
                    }
                    .onEnded { _ in dragStartListWidth = nil }
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
                Spacer()
                Text(Self.dateFormatter.string(from: fireCase.occurredAt))
                    .font(AppTypography.subheadline)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    selectedCaseID == fireCase.id
                    ? Color.gray200
                    : Color.clear
                )
        )
        .contextMenu {
            moveMenu(fireCase)
            Button(Copy.deleteCase, systemImage: "trash", role: .destructive) {
                deletingCase = fireCase
            }
        }
    }
    
    /// 길게 눌러 사건을 사용자 목록에 넣거나 옮기거나 뺀다. 사건은 목록 하나에만 들어간다
    // TEMP: Figma에 사건을 목록에 넣는 화면이 없어 길게 누르기 메뉴로 임의 구현 — 팀 확인 필요
    @ViewBuilder
    private func moveMenu(_ fireCase: FireCase) -> some View {
        if !folders.isEmpty {
            Menu(Copy.moveToFolder, systemImage: "folder") {
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
        if fireCase.folder != nil {
            Button(Copy.removeFromFolder, systemImage: "folder.badge.minus") {
                move(fireCase, to: nil)
            }
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
    
    /// nil이면 목록에서 빼서 상태에 따라 조사 중·조사 종결에 보이게 한다
    private func move(_ fireCase: FireCase, to folder: CaseFolder?) {
        fireCase.folder = folder
        try? modelContext.save()
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
        static let minimumListWidth: CGFloat = 250
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
            onOpen: { _ in }
        )
    }
    .modelContainer(for: FireCase.self, inMemory: true)
}

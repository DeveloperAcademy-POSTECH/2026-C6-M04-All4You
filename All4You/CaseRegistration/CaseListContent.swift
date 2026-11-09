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
    @Query private var allCases: [FireCase]
    
    let filter: CaseFilter
    let searchText: String
    @Binding var selectedCaseID: FireCase.ID?
    let onRegister: () -> Void
    /// 미리보기의 "사건 열기"를 누르면 그 사건을 연다
    let onOpen: (FireCase) -> Void

    private var cases: [FireCase] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let searched = keyword.isEmpty
            ? allCases
            : allCases.filter { $0.address.localizedStandardContains(keyword) }

        switch filter {
        case .recent:
            return searched.sorted { $0.lastViewedAt > $1.lastViewedAt }
        case .inProgress:
            return searched.filter { $0.status == .inProgress }
                .sorted { $0.occurredAt > $1.occurredAt }
        case .closed:
            return searched.filter { $0.status == .closed }
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
                HStack(spacing: 0) {
                    caseList
                        .frame(maxWidth: selectedCase == nil ? .infinity : Layout.listWidthWithPreview)
                    if let selectedCase {
                        CasePreviewView(fireCase: selectedCase, onOpen: { onOpen(selectedCase) })
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .animation(.default, value: selectedCaseID)
            }
        }
        .navigationTitle(allCases.isEmpty ? "" : filter.title)
        .navigationBarTitleDisplayMode(allCases.isEmpty ? .inline : .large)
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
    
    @ViewBuilder
    private var caseList: some View {
        List(selection: $selectedCaseID) {
            // 최근 열람은 달별로 나누지 않는다
            if filter == .recent {
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
        HStack {
            Text(fireCase.title)
            Spacer()
            Text(Self.dateFormatter.string(from: fireCase.occurredAt))
                .font(AppTypography.subheadline)
                .foregroundStyle(.secondary)
        }
        .tag(fireCase.id)
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
        static let listWidthWithPreview: CGFloat = 380
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
    }
}

#Preview("SwiftData 빈 목록") {
    @Previewable @State var selectedCaseID: FireCase.ID?

    NavigationStack {
        CaseListContent(
            filter: .recent,
            searchText: "",
            selectedCaseID: $selectedCaseID,
            onRegister: {},
            onOpen: { _ in }
        )
    }
    .modelContainer(for: FireCase.self, inMemory: true)
}

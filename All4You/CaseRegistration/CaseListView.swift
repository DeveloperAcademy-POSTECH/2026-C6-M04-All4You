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
    
    @State private var showsSaveError = false
    @State private var saveErrorMessage = ""
    
    @State private var filter: CaseFilter = .recent
    @State private var selectedCaseID: FireCase.ID?
    @State private var searchText = ""
    @State private var isPresentingRegistration = false
    
    @State private var isPresentingFloorPlan = false
    @State private var pendingFloorPlan: FireCase?
    
    // 사이드바 / 탭 바 편집 상태 저장
    @AppStorage("caseListTabCustomization")
    private var customization: TabViewCustomization
    
    var body: some View {
        
        TabView(selection: $filter) {
            
            ForEach(CaseFilter.allCases, id: \.self) { item in
                
                Tab(
                    item.title,
                    systemImage: item.systemImage,
                    value: item
                ) {
                    caseTab(item)
                }
                .customizationID("case.\(item)")
            }
        }
        
        // 사이드바 / 상단 탭 바 전환
        .tabViewStyle(.sidebarAdaptable)
        
        // 사이드바 편집 설정
        .tabViewCustomization($customization)
        
        // 사이드바 헤더
        .tabViewSidebarHeader {
            logo
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )
                .transaction { transaction in
                    transaction.animation = nil
                }
        }
        
        .tint(.black)
        
        .onChange(of: filter) {
            selectedCaseID = nil
        }
        
        .sheet(
            isPresented: $isPresentingRegistration,
            onDismiss: {
                // 사건 등록 시트가 닫힌 후 전체 화면 표시
                if pendingFloorPlan != nil {
                    isPresentingFloorPlan = true
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
                    filter = .inProgress
                    
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
        .fullScreenCover(
            isPresented: $isPresentingFloorPlan,
            onDismiss: {
                pendingFloorPlan = nil
            }
        ) {
            if let pendingFloorPlan {
                NavigationStack {
                    FloorPlanMethodSelectionView(
                        address: pendingFloorPlan.address,
                        createdAt: pendingFloorPlan.occurredAt
                    )
                }
            }
        }
        
    }
    
    private func presentRegistration() {
        isPresentingRegistration = true
    }
}

// MARK: - 탭 내용

extension CaseListView {
    
    private func caseTab(_ item: CaseFilter) -> some View {
        NavigationStack {
            CaseListContent(
                filter: item,
                searchText: searchText,
                selectedCaseID: $selectedCaseID,
                onRegister: presentRegistration
            )
            .toolbar {
                detailToolbar
            }
            .searchable(
                text: $searchText,
                placement: .toolbar,
                prompt: "제목, 사건명"
            )
        }
    }
}

// MARK: - 사이드바 헤더

extension CaseListView {
    
    private var logo: some View {
        
        VStack(alignment: .leading, spacing: 24) {
            
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
            
            Text(Copy.caseList)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
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
    }
}

// MARK: - Preview (실제 기기 DB와 분리된 빈 저장소)

#Preview("사건 없음") {
    CaseListView()
        .modelContainer(for: FireCase.self, inMemory: true)
}

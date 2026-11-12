//
//  FloorPlanMemoView.swift
//  All4You
//
//  Created by 채유성 on 11/09/26.
//

import SwiftUI

struct FloorPlanMemoView: View {
    let sections: [FloorPlanMemoSection]
    
    // nil이면 전체, 값이 있으면 Room.id에 해당하는 메모만 보여줌
    @State private var selectedLocationID: String?
    @State private var selectedMemoID: FloorPlanMemo.ID?
    @State private var isDetailExpanded = false
    @State private var listWidthFraction: CGFloat = 890 / 1352
    @State private var dragStartListWidth: CGFloat?
    @State private var splitDragOffset: CGFloat = 0
    @State private var restoreDragWidth: CGFloat = 0
    
    private let splitHandleWidth: CGFloat = 24
    private let pickerBottomClearance: CGFloat = 82
    
    init(sections: [FloorPlanMemoSection] = []) {
        self.sections = sections
    }
    
    init(
        sections: [FloorPlanMemoSection],
        selectedMemoID: FloorPlanMemo.ID,
        isDetailExpanded: Bool
    ) {
        self.sections = sections
        _selectedMemoID = State(initialValue: selectedMemoID)
        _isDetailExpanded = State(initialValue: isDetailExpanded)
    }
    
    var body: some View {
        GeometryReader { proxy in
            if let selectedMemo {
                if isDetailExpanded {
                    expandedDetail(for: selectedMemo, in: proxy.size)
                        .transition(.opacity)
                } else {
                    let availableWidth = max(0, proxy.size.width - splitHandleWidth)
                    let currentListWidth = listWidth(in: availableWidth)
                    let currentDetailWidth = availableWidth - currentListWidth
                    
                    ZStack(alignment: .topLeading) {
                        Color(.systemBackground)
                        
                        // 드래그 위치를 바로 두 영역의 너비에 반영
                        memoList
                            .frame(width: currentListWidth, height: proxy.size.height)
                            .clipped()
                        
                        detailView(for: selectedMemo, presentation: .split)
                            .safeAreaInset(edge: .bottom, spacing: 0) {
                                Color.clear.frame(height: pickerBottomClearance)
                            }
                            .frame(width: currentDetailWidth, height: proxy.size.height)
                            .offset(x: currentListWidth + splitHandleWidth)
                        
                        FloorPlanMemoSplitHandle()
                            .frame(width: splitHandleWidth, height: proxy.size.height)
                            .offset(x: currentListWidth)
                            .gesture(
                                DragGesture(minimumDistance: 1)
                                    .onChanged { value in
                                        guard !isDetailExpanded else { return }
                                        if dragStartListWidth == nil {
                                            dragStartListWidth = clampedListWidth(
                                                availableWidth * listWidthFraction,
                                                in: availableWidth
                                            )
                                        }
                                        
                                        let proposedWidth = (dragStartListWidth ?? 0)
                                        + value.translation.width
                                        if availableWidth > 0,
                                           proposedWidth < minimumListWidth(in: availableWidth) {
                                            // 목록 최소 너비를 넘어 왼쪽으로 당기면 상세 화면으로 즉시 전환
                                            listWidthFraction = minimumListWidth(in: availableWidth)
                                            / availableWidth
                                            dragStartListWidth = nil
                                            splitDragOffset = 0
                                            withAnimation(.easeInOut(duration: 0.25)) {
                                                isDetailExpanded = true
                                            }
                                            return
                                        }
                                        splitDragOffset = value.translation.width
                                    }
                                    .onEnded { value in
                                        guard !isDetailExpanded else { return }
                                        if availableWidth > 0 {
                                            let width = clampedListWidth(
                                                (dragStartListWidth ?? availableWidth * listWidthFraction)
                                                + value.translation.width,
                                                in: availableWidth
                                            )
                                            listWidthFraction = width / availableWidth
                                        }
                                        dragStartListWidth = nil
                                        splitDragOffset = 0
                                    }
                            )
                            .accessibilityAdjustableAction { direction in
                                guard availableWidth > 0 else { return }
                                let step: CGFloat = 40
                                let delta = direction == .increment ? step : -step
                                let width = clampedListWidth(
                                    availableWidth * listWidthFraction + delta,
                                    in: availableWidth
                                )
                                listWidthFraction = width / availableWidth
                            }
                    }
                    .clipped()
                    .overlay(alignment: .topLeading) {
                        Rectangle()
                            .fill(Color(.separator).opacity(0.6))
                            .frame(width: 1, height: proxy.size.height + 140)
                            .offset(x: currentListWidth + splitHandleWidth / 2 - 0.5, y: -140)
                            .allowsHitTesting(false)
                    }
                    .transition(.opacity)
                    .transaction {
                        if dragStartListWidth != nil { $0.animation = nil }
                    }
                }
            } else if sections.isEmpty {
                emptyView
            } else {
                memoList
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .overlay(alignment: .bottom) {
            if !isDetailExpanded && !sections.isEmpty {
                locationPicker
                    .padding(.bottom, 32)
            }
        }
        .toolbar(isDetailExpanded ? .hidden : .visible, for: .navigationBar)
        .toolbar(isDetailExpanded ? .hidden : .visible, for: .tabBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .overlay(alignment: .bottomTrailing) {
            if selectedMemo != nil {
                expansionButton
                    .padding(24)
            }
        }
        .onChange(of: selectedLocationID) {
            selectedMemoID = nil
            isDetailExpanded = false
            restoreDragWidth = 0
        }
    }
    
    private var memoList: some View {
        List {
            ForEach(visibleSections) { section in
                Section {
                    ForEach(section.memos) { memo in
                        FloorPlanMemoRow(
                            memo: memo,
                            isSelected: memo.id == selectedMemoID,
                            showsDivider: memo.id != section.memos.last?.id,
                            action: {
                                selectedMemoID = selectedMemoID == memo.id ? nil : memo.id
                                isDetailExpanded = false
                            }
                        )
                        .listRowInsets(
                            EdgeInsets(top: 0, leading: 32, bottom: 0, trailing: 32)
                        )
                        .listRowSeparator(.hidden)
                    }
                } header: {
                    FloorPlanMemoSectionHeader(title: section.locationName)
                        .listRowInsets(
                            EdgeInsets(top: 0, leading: 64, bottom: 0, trailing: 64)
                        )
                }
            }
        }
        .listStyle(.plain)
        .listSectionSpacing(32)
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: pickerBottomClearance)
        }
    }
    
    private var emptyView: some View {
        ContentUnavailableView {
            Label("작성된 메모가 없어요", systemImage: "bubble.left")
        } description: {
            Text("도면에서 \(Image(systemName: "plus.bubble"))버튼을 눌러 메모를 작성해 주세요")
        }
    }
    
    /// 도면에 실제로 있는 장소만 동적으로 보여 준다.
    private var locationPicker: some View {
        Picker("메모 위치", selection: $selectedLocationID) {
            Text("전체")
                .tag(String?.none)
            ForEach(sections) { section in
                Text(section.locationName)
                    .tag(Optional(section.id))
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.large)
        .fixedSize(horizontal: true, vertical: false)
        .frame(minWidth: 180, minHeight: 50)
        .background {
            Capsule()
                .fill(Color.gray100)
                .padding(.top, 1)
        }
    }
    
    private func expandedDetail(for memo: FloorPlanMemo, in size: CGSize) -> some View {
        let availableWidth = max(0, size.width - splitHandleWidth)
        let minimumWidth = minimumListWidth(in: availableWidth)
        
        return ZStack(alignment: .topLeading) {
            Color(.systemBackground)
            
            if restoreDragWidth > 0 {
                memoList
                    .frame(width: minimumWidth, height: size.height)
                    .mask(alignment: .leading) {
                        Rectangle().frame(width: restoreDragWidth)
                    }
            }
            
            detailView(for: memo, presentation: .expanded)
                .frame(width: size.width, height: size.height)
                .offset(x: restoreDragWidth)
            
            if restoreDragWidth > 0 {
                FloorPlanMemoSplitHandle()
                    .frame(width: splitHandleWidth, height: size.height)
                    .offset(x: restoreDragWidth)
                    .allowsHitTesting(false)
            }
            
            // 화면 왼쪽 가장자리에서 오른쪽으로 당겨 목록 다시 표시
            Color.clear
                .frame(width: 48, height: size.height)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 8)
                        .onChanged { value in
                            guard value.translation.width > 0,
                                  abs(value.translation.width) > abs(value.translation.height)
                                    else { return }
                            restoreDragWidth = min(value.translation.width, minimumWidth)
                        }
                        .onEnded { _ in
                            let shouldRestore = restoreDragWidth >= min(100, minimumWidth * 0.35)
                            withAnimation(.easeInOut(duration: 0.25)) {
                                restoreDragWidth = 0
                                if shouldRestore, availableWidth > 0 {
                                    listWidthFraction = minimumWidth / availableWidth
                                    isDetailExpanded = false
                                }
                            }
                        }
                )
        }
        .clipped()
    }
    
    private func detailView(
        for memo: FloorPlanMemo,
        presentation: FloorPlanMemoDetailView.Presentation
    ) -> some View {
        FloorPlanMemoDetailView(
            memo: memo,
            presentation: presentation
        )
    }
    
    private var expansionButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                restoreDragWidth = 0
                isDetailExpanded.toggle()
            }
        } label: {
            Image(systemName: isDetailExpanded
                  ? "arrow.down.right.and.arrow.up.left"
                  : "arrow.down.left.and.arrow.up.right")
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(width: 56, height: 56)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(
            .regular.tint(Color(uiColor: .systemGray5)).interactive(),
            in: .circle
        )
        .accessibilityLabel(isDetailExpanded ? "상세 축소" : "상세 확대")
    }
    
    private var selectedMemo: FloorPlanMemo? {
        guard let selectedMemoID else { return nil }
        
        for section in sections {
            if let memo = section.memos.first(where: { $0.id == selectedMemoID }) {
                return memo
            }
        }
        return nil
    }
    
    private var visibleSections: [FloorPlanMemoSection] {
        guard let selectedLocationID else { return sections }
        return sections.filter { $0.id == selectedLocationID }
    }
    
    private func listWidth(in availableWidth: CGFloat) -> CGFloat {
        clampedListWidth(
            (dragStartListWidth ?? availableWidth * listWidthFraction) + splitDragOffset,
            in: availableWidth
        )
    }
    
    private func clampedListWidth(_ width: CGFloat, in availableWidth: CGFloat) -> CGFloat {
        let minimumListWidth = minimumListWidth(in: availableWidth)
        let minimumDetailWidth = min(320, availableWidth * 0.45)
        return min(max(width, minimumListWidth), availableWidth - minimumDetailWidth)
    }
    
    private func minimumListWidth(in availableWidth: CGFloat) -> CGFloat {
        min(280, availableWidth * 0.45)
    }
}

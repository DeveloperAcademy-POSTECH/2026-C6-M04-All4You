//
//  FlorPlanExportView.swift
//  All4You
//
//  Created by 채유성 on 11/8/26.
//

import SwiftUI

struct FloorPlanExportView: View {
    
    @Environment(\.dismiss) private var dismiss
    @State private var planType: SavedPlanType = .twoD
    @State private var photoDisplay: PhotoDisplayOption = .bookmarked
    @State private var showsCaptureDirection = true
    @State private var showsRoomNames = true
    @State private var showsFurniture = true
    @State private var showsStamps = true
    @State private var isSaving = false
    @State private var isSavedToastVisible = false
    @State private var toastDismissTask: Task<Void, Never>?
    @State private var saveError: String?
    
    // 실제 사진 보관함 저장이 끝나면 반환하고, 실패하면 오류를 던지는 저장 작업
    let saveAction: (FloorPlanSaveConfiguration) async throws -> Void
    
    init(saveAction: @escaping (FloorPlanSaveConfiguration) async throws -> Void = { _ in }) {
        self.saveAction = saveAction
    }
    
    var body: some View {
        NavigationStack {
            HStack(spacing: 24) {
                FloorPlanSavePreview(planType: planType)
                FloorPlanSaveOptions(
                    planType: $planType,
                    photoDisplay: $photoDisplay,
                    showsCaptureDirection: $showsCaptureDirection,
                    showsRoomNames: $showsRoomNames,
                    showsFurniture: $showsFurniture,
                    showsStamps: $showsStamps
                )
                .frame(width: 370)
            }
            .padding(24)
            .offset(y: -80)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("도면 저장")
                        .font(.title.weight(.bold))
                        .offset(y: 3)
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color(uiColor: .systemGray))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.tint(Color(uiColor: .systemGray5)).interactive(), in: .circle)
                    .offset(y: 3)
                    .accessibilityLabel("닫기")
                }
                .sharedBackgroundVisibility(.hidden)
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .offset(y: -1)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.tint(.brand500).interactive(), in: .circle)
                    .offset(y: 3)
                    .accessibilityLabel("저장")
                    .disabled(isSaving)
                }
                .sharedBackgroundVisibility(.hidden)
            }
        }
        .overlay(alignment: .bottom) {
            if isSavedToastVisible {
                FloorPlanSavedToast()
                    .padding(.bottom, 28)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .zIndex(1)
            }
        }
        .alert("도면을 저장하지 못했어요", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("확인", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "다시 시도해 주세요")
        }
        .onDisappear {
            toastDismissTask?.cancel()
        }
        .presentationSizing(FloorPlanSaveSheetSizing())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.white)
    }
    
    @MainActor
    private func save() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        
        do {
            try await saveAction(configuration)
            showSavedToast()
        } catch {
            saveError = error.localizedDescription
        }
    }
    
    @MainActor
    private func showSavedToast() {
        toastDismissTask?.cancel()
        withAnimation(.easeInOut(duration: 0.2)) {
            isSavedToastVisible = true
        }
        toastDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                isSavedToastVisible = false
            }
        }
    }
    
    private var configuration: FloorPlanSaveConfiguration {
        FloorPlanSaveConfiguration(
            planType: planType,
            photoDisplay: photoDisplay,
            showsCaptureDirection: showsCaptureDirection,
            showsRoomNames: showsRoomNames,
            showsFurniture: showsFurniture,
            showsStamps: showsStamps
        )
    }
}

private struct FloorPlanSaveSheetSizing: PresentationSizing {
    func proposedSize(
        for root: PresentationSizingRoot,
        context: PresentationSizingContext
    ) -> ProposedViewSize {
        ProposedViewSize(width: 1134, height: 800)
    }
}

private struct FloorPlanSavePreview: View {
    let planType: SavedPlanType
    
    var body: some View {
        ZStack {
            // TODO: 실제 데이터랑 연결해야함
            ContentUnavailableView {
                Label("도면 자리", systemImage: planType.previewSymbol)
            } description: {
                Text("저장할 \(planType.title) 도면이 이곳에 표시됩니다.")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(.rect(cornerRadius: 24))
        .accessibilityLabel("저장할 \(planType.title) 도면 미리보기")
    }
}

private struct FloorPlanSaveOptions: View {
    @Binding var planType: SavedPlanType
    @Binding var photoDisplay: PhotoDisplayOption
    @Binding var showsCaptureDirection: Bool
    @Binding var showsRoomNames: Bool
    @Binding var showsFurniture: Bool
    @Binding var showsStamps: Bool
    
    var body: some View {
        
        VStack(alignment: .leading, spacing: 40) {
            
            FloorPlanSavePickerSection(
                title: "저장할 도면",
                selection: $planType
            )
            
            FloorPlanSavePickerSection(
                title: "사진 표시",
                selection: $photoDisplay
            )
            
            VStack(spacing: 16) {
                Toggle("촬영 방향", isOn: $showsCaptureDirection)
                    .tint(Color("Brand500"))
                Toggle("공간 이름", isOn: $showsRoomNames)
                    .tint(Color("Brand500"))
                Toggle("가구", isOn: $showsFurniture)
                    .tint(Color("Brand500"))
                Toggle("스탬프", isOn: $showsStamps)
                    .tint(Color("Brand500"))
            }
            .font(.title3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        
    }
}

private struct FloorPlanSavePickerSection<Option>: View where Option: CaseIterable & Hashable & Identifiable & TitledOption {
    let title: LocalizedStringKey
    @Binding var selection: Option
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title3)
                .foregroundStyle(.secondary)
            
            Picker(title, selection: $selection) {
                ForEach(Array(Option.allCases)) { option in
                    Text(option.title).tag(option)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .controlSize(.large)
        }
    }
}

struct FloorPlanSaveConfiguration {
    let planType: SavedPlanType
    let photoDisplay: PhotoDisplayOption
    let showsCaptureDirection: Bool
    let showsRoomNames: Bool
    let showsFurniture: Bool
    let showsStamps: Bool
}

protocol TitledOption {
    var title: LocalizedStringResource { get }
}

#Preview {
    FloorPlanSaveSheetPreviewHost()
}

private struct FloorPlanSaveSheetPreviewHost: View {
    @State private var isSavePresented = true
    
    var body: some View {
        Button("도면 저장 열기") {
            isSavePresented = true
        }
        .sheet(isPresented: $isSavePresented) {
            FloorPlanExportView { _ in }
        }
    }
}

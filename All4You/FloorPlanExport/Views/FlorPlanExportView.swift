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
    /// 미리보기가 화면에 놓인 자리(전역 좌표). 3D는 이 자리를 화면 그대로 찍어 저장한다
    @State private var previewFrame: CGRect = .zero
    
    /// 저장할 도면
    let planData: PlanData
    /// 도면에 사진 핀으로 보일 사진 (메인에서 고른 조사 차수의 사진)
    let photos: [LoadedPhoto]
    
    var body: some View {
        NavigationStack {
            HStack(spacing: 24) {
                FloorPlanSavePreview(planType: planType, content: content)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { previewFrame = $0 }
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
            // 2D는 같은 그림을 큰 이미지로 다시 그리고, 3D는 미리보기 화면을 그대로 찍는다
            let image = planType == .twoD
                ? FloorPlanExporter.render2D(content)
                : FloorPlanExporter.captureScreen(in: previewFrame)
            guard let image else { throw FloorPlanExporter.ExportError.imageFailed }
            try await FloorPlanExporter.saveToPhotoLibrary(image)
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
    
    /// 옵션을 반영한 도면과 사진 핀. 미리보기와 저장이 같은 값을 쓴다
    private var content: FloorPlanExportContent {
        FloorPlanExportContent(planData: planData, photos: photos, configuration: configuration)
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
    let content: FloorPlanExportContent
    
    var body: some View {
        ZStack {
            switch planType {
            case .twoD:
                FloorPlanExport2DCanvas(content: content)
            case .threeD:
                // 3D는 돌리고 확대해 원하는 각도를 맞춘 뒤 그 화면 그대로 저장한다
                FloorPlan3DView(
                    planData: plan3D,
                    selection: nil,
                    onTap: { _ in },
                    onEdit: { _ in },
                    pins: pins3D,
                    pinView: pinView3D
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(.rect(cornerRadius: 24))
        .accessibilityLabel("저장할 \(planType.title) 도면 미리보기")
    }
}

// 3D 미리보기
extension FloorPlanSavePreview {
    /// 공간 이름을 끄면 3D 이름 라벨도 숨긴다 (3D에서 방은 이름 라벨로만 보인다)
    private var plan3D: PlanData {
        var plan = content.planData
        if !content.showsRoomNames {
            plan.rooms = []
        }
        return plan
    }

    /// 사진 핀을 장소 이름 자리에 띄운다 (도면 탭 3D와 같은 높이)
    private var pins3D: [Plan3DPin] {
        content.planData.rooms
            .filter { content.pins[$0.id] != nil }
            .map { Plan3DPin(id: $0.id, point: SIMD2($0.labelX, $0.labelY), height: Self.photoPinHeight) }
    }

    private func pinView3D(_ roomID: String) -> AnyView {
        guard let room = content.planData.rooms.first(where: { $0.id == roomID }),
              let pin = content.pins[roomID] else { return AnyView(EmptyView()) }
        return AnyView(
            PhotoPinView(roomName: room.name, pin: pin, isSelected: false, isDimmed: false, onTap: {})
                .allowsHitTesting(false)
        )
    }

    /// 사진 핀을 띄우는 높이 (m)
    private static let photoPinHeight = 1.5
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
            FloorPlanExportView(planData: DummyFloorPlan.planData, photos: [])
        }
    }
}

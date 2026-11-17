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
    @State private var photoDisplay: PhotoDisplayOption
    @State private var showsCaptureDirection = true
    @State private var showsRoomNames = true
    @State private var showsFurnitureLabels = true
    @State private var showsStamps = true
    @State private var isSaving = false
    @State private var isSavedToastVisible = false
    @State private var toastDismissTask: Task<Void, Never>?
    @State private var saveError: String?
    /// 도면과 함께 내보낸 사진 중 저장하지 못한 사진 안내 (저장한 장수, 못 한 장수)
    @State private var photoSaveShortfall: PhotoSaveShortfall?
    @State private var savedMessage = FloorPlanSavedToast.defaultMessage
    /// 미리보기가 화면에 놓인 자리(전역 좌표). 3D는 이 자리를 화면 그대로 찍어 저장한다
    @State private var previewFrame: CGRect = .zero
    /// 2D 미리보기의 확대·회전·이동한 시야. nil이면 처음 시야. 저장하는 2D 그림도 이 시야 그대로다
    @State private var planScreen: PlanScreen?
    
    /// 저장할 도면
    let planData: PlanData
    /// 도면에 사진 핀으로 보일 사진 (메인에서 고른 조사 차수의 사진)
    let photos: [LoadedPhoto]
    /// 사진을 함께 저장할 사진 보관함 앨범 이름 ("사건명 · 1차 조사")
    let albumTitle: String
    
    init(planData: PlanData, photos: [LoadedPhoto], albumTitle: String) {
        self.planData = planData
        self.photos = photos
        self.albumTitle = albumTitle
        _photoDisplay = State(initialValue: photos.isEmpty ? .hidden : .bookmarked)
    }
    
    var body: some View {
        NavigationStack {
            HStack(spacing: 24) {
                FloorPlanSavePreview(planType: planType, content: content, planScreen: $planScreen)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { previewFrame = $0 }
                    // 미리보기 크기가 바뀌면 맞춰 둔 시야가 어긋나므로 처음 시야로 돌린다
                    .onChange(of: previewFrame.size) { planScreen = nil }
                FloorPlanSaveOptions(
                    planType: $planType,
                    photoDisplay: $photoDisplay,
                    showsCaptureDirection: $showsCaptureDirection,
                    showsRoomNames: $showsRoomNames,
                    showsFurnitureLabels: $showsFurnitureLabels,
                    showsStamps: $showsStamps,
                    hasPhotos: content.hasPhotos,
                    hasVisiblePhotos: content.hasVisiblePhotos,
                    hasDirectionalPhotos: content.hasDirectionalPhotos
                )
                .frame(width: 370)
                .offset(y: -80)
            }
            .padding(24)
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
                FloorPlanSavedToast(message: savedMessage)
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
        .alert(Text(Copy.shortfallTitle), isPresented: Binding(
            get: { photoSaveShortfall != nil },
            set: { if !$0 { photoSaveShortfall = nil } }
        ), presenting: photoSaveShortfall) { _ in
            Button("확인", role: .cancel) { photoSaveShortfall = nil }
        } message: { shortfall in
            Text(Copy.shortfallMessage(saved: shortfall.saved, failed: shortfall.failed))
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
            // 2D는 같은 그림을 같은 시야로 큰 이미지로 다시 그리고, 3D는 미리보기 화면을 그대로 찍는다
            let image = planType == .twoD
            ? FloorPlanExporter.render2D(content, screen: planScreen, size: previewFrame.size)
            : FloorPlanExporter.captureScreen(in: previewFrame)
            guard let image else { throw FloorPlanExporter.ExportError.imageFailed }
            // 사진 표시를 켠 경우 그 사진도 함께 저장한다 (표시 안 함이면 도면만)
            let exportPhotos = FloorPlanExporter.numberedPhotos(photoDisplay.visiblePhotos(from: photos), rooms: planData.rooms)
            let failedCount = try await FloorPlanExporter.saveToPhotoLibrary(
                image,
                fileName: Copy.planFileName(planType),
                photos: exportPhotos,
                albumTitle: albumTitle
            )
            let savedCount = exportPhotos.count - failedCount
            if failedCount > 0 {
                photoSaveShortfall = PhotoSaveShortfall(saved: savedCount, failed: failedCount)
            } else {
                savedMessage = savedCount > 0 ? FloorPlanSavedToast.message(photoCount: savedCount) : FloorPlanSavedToast.defaultMessage
                showSavedToast()
            }
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
            showsFurnitureLabels: showsFurnitureLabels,
            showsStamps: showsStamps
        )
    }
}

/// 사진 일부를 저장하지 못했을 때 알리는 값
private struct PhotoSaveShortfall {
    let saved: Int
    let failed: Int
}

extension FloorPlanExportView {
    private enum Copy {
        static let shortfallTitle = "사진 일부를 저장하지 못했어요"
        
        static func shortfallMessage(saved: Int, failed: Int) -> String {
            "도면과 사진 \(saved)장은 저장했고, \(failed)장은 저장하지 못했어요"
        }
        
        /// 사진 보관함에 저장하는 도면 이미지의 파일명
        static func planFileName(_ type: SavedPlanType) -> String {
            "도면_\(type == .twoD ? "2D" : "3D").png"
        }
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
    @Binding var planScreen: PlanScreen?
    
    var body: some View {
        ZStack {
            switch planType {
            case .twoD:
                FloorPlanExport2DPreview(content: content, screen: $planScreen)
            case .threeD:
                // 3D는 돌리고 확대해 원하는 각도를 맞춘 뒤 그 화면 그대로 저장한다
                FloorPlan3DView(
                    planData: plan3D,
                    selection: nil,
                    onTap: { _ in },
                    onEdit: { _ in },
                    pins: pins3D,
                    pinView: pinView3D,
                    photoMarkers: photoMarkers3D,
                    showsCompass: true,
                    compassTopInset: 16,
                    showsFurnitureLabels: content.showsFurnitureLabels
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
    
    /// 촬영 위치 원형 마커는 유지하고, 방향 원뿔만 토글로 표시
    private var photoMarkers3D: [Plan3DPhotoMarker] {
        content.photoMarkers.map { marker in
            Plan3DPhotoMarker(
                id: marker.id,
                placement: marker.placement,
                showsDirection: content.showsCaptureDirection && marker.placement.yaw != nil,
                isDimmed: false
            )
        }
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
    @Binding var showsFurnitureLabels: Bool
    @Binding var showsStamps: Bool
    let hasPhotos: Bool
    let hasVisiblePhotos: Bool
    let hasDirectionalPhotos: Bool
    
    var body: some View {
        
        VStack(alignment: .leading, spacing: 40) {
            
            FloorPlanSavePickerSection(
                title: "저장할 도면",
                selection: $planType
            )
            
            VStack(alignment: .leading, spacing: 8) {
                FloorPlanSavePickerSection(
                    title: "사진 표시",
                    selection: $photoDisplay,
                    isEnabled: hasPhotos
                )
                if !hasPhotos {
                    Text("표시할 사진이 없어요")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("촬영 방향", isOn: Binding(
                        get: { hasDirectionalPhotos && showsCaptureDirection },
                        set: { showsCaptureDirection = $0 }
                    ))
                    .tint(Color("Brand500"))
                    .disabled(!hasDirectionalPhotos)
                    if hasPhotos && !hasDirectionalPhotos {
                        Text(directionUnavailableMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Toggle("공간 이름", isOn: $showsRoomNames)
                    .tint(Color("Brand500"))
                Toggle("가구 이름", isOn: $showsFurnitureLabels)
                    .tint(Color("Brand500"))
                Toggle("스탬프", isOn: $showsStamps)
                    .tint(Color("Brand500"))
            }
            .font(.title3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        
    }
    
    private var directionUnavailableMessage: String {
        switch photoDisplay {
        case .hidden:
            return "사진 표시를 켜면 촬영 방향을 선택할 수 있어요"
        case .all:
            return "북마크를 선택하면 촬영 방향을 표시할 수 있어요"
        case .bookmarked:
            return hasVisiblePhotos ? "방향 정보가 포함된 사진이 없어요" : "북마크한 사진이 없어요"
        }
    }
}

private struct FloorPlanSavePickerSection<Option>: View where Option: CaseIterable & Hashable & Identifiable & TitledOption {
    let title: LocalizedStringKey
    @Binding var selection: Option
    var isEnabled = true
    
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
            .disabled(!isEnabled)
        }
    }
}

struct FloorPlanSaveConfiguration {
    let planType: SavedPlanType
    let photoDisplay: PhotoDisplayOption
    let showsCaptureDirection: Bool
    let showsRoomNames: Bool
    let showsFurnitureLabels: Bool
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
            FloorPlanExportView(planData: DummyFloorPlan.planData, photos: [], albumTitle: "청암로 77 · 1차 조사")
        }
    }
}

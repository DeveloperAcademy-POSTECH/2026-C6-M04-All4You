//
//  FloorPlanMethodSelectionView.swift
//  All4You
//
//  Created by 채유성 on 11/1/26.
//

import PDFKit
import PencilKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import UIKit

// 평면도 생성 방식 선택 화면
// 이전 화면에서 사건을 전달받음
// 계속 버튼을 누르면 선택한 방식에 따라 이 View에서 다음 화면으로 이동함
struct FloorPlanMethodSelectionView: View {
    /// 평면도를 만들 사건. 주소는 상단 바 부제로 쓰고, 변환한 도면은 이 사건에 저장한다
    let fireCase: FireCase

    @Environment(\.dismiss) private var dismiss

    // 선택 상태와 이동 상태를 분리 (항목을 누르는 것만으로 화면이 이동하지 않도록 방지)
    @State private var selectedSourceType: FloorPlanSourceType?
    @State private var destination: FloorPlanSourceType?
    @State private var drawingCanvas = PKCanvasView()
    /// 스케치 위에 놓은 스탬프
    @State private var sketchStamps: [SketchStamp] = []
    @State private var isConvertingDrawing = false
    @State private var showsDrawingResult = false
    @State private var drawingSaveError: String?
    @State private var isImportMenuPresented = false
    @State private var importMethod: ImportMethod?
    @State private var isCheckingPhotoPermission = false
    @State private var showsPhotoSettings = false
    @State private var showsFileImportError = false
    @State private var showsAlbum = false
    @State private var importedImage: UIImage?
    @State private var croppedImage: UIImage?
    @State private var showsImportCrop = false
    @State private var isFileImporterPresented = false
    @State private var isCameraPresented = false
    /// 스캔 결과를 바꾼 도면. 변환 화면에 흐리게 깔고, 화면이 끝나면 저장한다
    @State private var scannedPlan: PlanData?
    /// 스캔 중 찍은 사진. 도면을 저장할 때 사건 사진으로 함께 저장하고, 촬영 위치의 장소에 놓는다
    @State private var scannedPhotos: [ScanPhoto] = []
    /// 스캔 원본(JSON). 변환한 도면과 함께 저장한다
    @State private var scannedOriginal: Data?
    /// 스캔 도면을 저장하지 못했을 때의 알림 문구
    @State private var scanSaveError: String?
    
    private enum ImportMethod {
        case camera, album, file
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color(uiColor: .systemGray6)
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 24) {
                Text("평면도를 어떻게 준비할까요?")
                    .font(.title2.bold())
                
                VStack(spacing: 15) {
                    ForEach(FloorPlanSourceType.allCases) { sourceType in
                        FloorPlanMethodRow(
                            sourceType: sourceType,
                            isSelected: selectedSourceType == sourceType
                        ) {
                            // 같은 항목을 다시 누르면 선택을 해제하고 계속 버튼도 비활성화
                            selectedSourceType = selectedSourceType == sourceType ? nil : sourceType
                            importMethod = nil
                            // 외부 가져오기 메뉴는 해당 항목이 선택되어 있을 때만 표시
                            isImportMenuPresented = selectedSourceType == .externalImport
                        }
                        .frame(height: 80)
                    }
                }
            }
            .frame(maxWidth: 642)
            // 공용 상단 바가 16만큼 올라가고 얇아져서, 내용이 있던 자리에 그대로 있게 위 여백을 그만큼 늘렸다 (169 + 16)
            .padding(EdgeInsets(top: 185, leading: 24, bottom: 24, trailing: 24))
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationBarTitleDisplayMode(.inline)
        .backOnlyToolbar(title: "목록으로", customLayout: true) {
            // 사건 목록이 전체 화면으로 띄운 화면이라 닫으면 목록으로 돌아간다
            dismiss()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            continueButton
                .frame(maxWidth: 642)
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity)
        }
        .overlay(alignment: .center) {
            if isImportMenuPresented {
                ExternalImportGlassMenu(
                    onCameraTap: {
                        isImportMenuPresented = false
                        importMethod = .camera
                    },
                    onPhotoLibraryTap: {
                        isImportMenuPresented = false
                        importMethod = .album
                    },
                    onFileTap: {
                        isImportMenuPresented = false
                        importMethod = .file
                    }
                )
                .offset(x: 340, y: 80)
                .transition(.opacity.combined(with: .scale(scale: 0.80, anchor: .topLeading)))
            }
        }
        .animation(.linear(duration: 0.15), value: isImportMenuPresented)
        .navigationDestination(item: $destination) { sourceType in
            switch sourceType {
            case .roomPlan:
                RoomPlanScanView(onUseResult: { _, structure, rooms, photos, plan in
                    scannedOriginal = try? RoomPlanOriginal(structure: structure, rooms: rooms).encoded()
                    scannedPhotos = photos
                    scannedPlan = plan
                })
                    .navigationDestination(item: $scannedPlan) { plan in
                        ConversionLoadingView(planData: plan) {
                            saveScannedPlan(plan)
                        }
                    }
                    .alert("도면 저장 실패", isPresented: Binding(
                        get: { scanSaveError != nil },
                        set: { if !$0 { scanSaveError = nil } }
                    )) {
                        Button("확인", role: .cancel) {}
                    } message: {
                        Text(scanSaveError ?? "")
                    }
            case .iPadDrawing:
                drawingFlow
            case .externalImport:
                EmptyView()
            }
        }
        // 앨범과 파일이 같은 영역 조정 및 결과 화면을 사용한다.
        .navigationDestination(isPresented: $showsImportCrop) {
            if let croppedImage {
                FloorPlanExternalImportResultView(
                    image: croppedImage,
                    address: fireCase.address,
                    onBack: { self.croppedImage = nil },
                    onSave: saveImportedResult
                )
            } else if let importedImage {
                FloorPlanImportCropView(
                    source: importedImage,
                    address: fireCase.address,
                    onRetake: { showsImportCrop = false },
                    onConfirm: { croppedImage = $0 }
                )
            }
        }
        // 사진을 확정한 경우에만 시트가 닫힌 뒤 크롭 화면을 연다.
        .sheet(isPresented: $showsAlbum, onDismiss: {
            if importedImage != nil {
                showsImportCrop = true
            }
        }) {
            FloorPlanAlbumView { image in
                importedImage = image
                showsAlbum = false
            }
            .presentationSizing(.page)
            .presentationDetents([.fraction(0.85), .large])
            .presentationDragIndicator(.visible)
        }
        .alert("사진 접근이 꺼져 있습니다", isPresented: $showsPhotoSettings) {
            Button("설정으로 이동") { PermissionService.openSettings() }
            Button("취소", role: .cancel) {}
        } message: {
            Text("사진을 불러오려면 설정에서 사진 접근을 허용해 주세요.")
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.image, .pdf]
        ) { result in
            importFile(result)
        }
        .alert("파일을 불러오지 못했어요", isPresented: $showsFileImportError) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("열 수 있는 이미지나 PDF 파일을 선택해 주세요.")
        }
        // 기존 도면 촬영 화면에서 촬영과 영역 조정을 이어서 처리한다.
        .fullScreenCover(isPresented: $isCameraPresented) {
            FloorPlanImportView(
                address: fireCase.address,
                onImport: saveImportedResult,
                onBack: { isCameraPresented = false }
            )
        }
    }
    
    private var continueButton: some View {
        ContinueButton(isEnabled: canContinue) {
            guard let selectedSourceType else { return }
            switch selectedSourceType {
            case .roomPlan, .iPadDrawing:
                // 룸플랜 스캔 & 직접 그리기는 다른 화면으로 이동
                isImportMenuPresented = false
                destination = selectedSourceType
            case .externalImport:
                switch importMethod {
                case .camera:
                    openCamera()
                case .album:
                    openAlbum()
                case .file:
                    isFileImporterPresented = true
                case nil:
                    break
                }
            }
        }
    }
    
    private var drawingFlow: some View {
        FloorPlanDrawingView(
            address: fireCase.address,
            onRetake: { destination = nil },
            onConfirm: { isConvertingDrawing = true },
            canvasView: $drawingCanvas,
            sketchStamps: $sketchStamps
        )
        .allowsHitTesting(!isConvertingDrawing)
        .overlay {
            if isConvertingDrawing {
                drawingConversionOverlay
            }
        }
        .task(id: isConvertingDrawing) {
            guard isConvertingDrawing else { return }
            do {
                try await Task.sleep(for: .seconds(3))
                try Task.checkCancellation()
            } catch {
                isConvertingDrawing = false
                return
            }
            isConvertingDrawing = false
            showsDrawingResult = true
        }
        .navigationDestination(isPresented: $showsDrawingResult) {
            FloorPlanDrawingResultView(
                address: fireCase.address,
                onBack: { showsDrawingResult = false },
                onSave: saveDrawingResult
            )
            .alert("도면 저장 실패", isPresented: Binding(
                get: { drawingSaveError != nil },
                set: { if !$0 { drawingSaveError = nil } }
            )) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(drawingSaveError ?? "")
            }
        }
    }

    /// 손그림 위에 기존 레이저 스캔 애니메이션을 보여 준 뒤 고정 결과로 이동한다.
    private var drawingConversionOverlay: some View {
        let bounds = drawingCanvas.drawing.bounds
        let sweep: ClosedRange<CGFloat>? = (bounds.isEmpty || bounds.isInfinite)
            ? nil : bounds.minY...bounds.maxY
        return Color.white.opacity(0.6)
            .overlay { ScanLaserView(range: sweep) }
            .accessibilityElement()
            .accessibilityLabel("도면 변환 중")
    }

    /// 손그림 내용과 관계없이 고정 결과를 사건에 저장하고 기존 편집 흐름으로 이어 간다.
    private func saveDrawingResult() {
        do {
            try fireCase.replaceFloorPlan(with: DrawingFloorPlanResult.planData, sourceType: .iPadDrawing)
        } catch {
            drawingSaveError = error.localizedDescription
        }
    }

    /// 외부 도면도 로컬 고정 결과를 사용한다. 성공하면 기존 도면 편집 흐름으로 이동한다.
    private func saveImportedResult() -> String? {
        do {
            try fireCase.replaceFloorPlan(with: DrawingFloorPlanResult.planData, sourceType: .externalImport)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    /// 스캔한 도면을 사건의 평면도로 저장한다. 쓸 수 없는 도면(스캔된 것이 없음)이거나 저장에 실패하면 저장하지 않고 변환 화면을 닫아 알린다.
    /// 평면도는 "있으면 항상 내용이 있다"여야 하므로 빈 도면은 replaceFloorPlan을 부르지 않는다
    private func saveScannedPlan(_ plan: PlanData) {
        guard plan.isUsable else {
            failScannedPlanSave(Copy.emptyScan)
            return
        }
        do {
            try fireCase.replaceFloorPlan(with: plan, sourceType: .roomPlan, roomPlanData: scannedOriginal)
        } catch {
            failScannedPlanSave(error.localizedDescription)
            return
        }
        // 도면과 같은 시점에 저장해야 다음 화면(PhotoStore)이 사진을 함께 읽는다
        fireCase.addScanPhotos(scannedPhotos, plan: plan)
        scannedPhotos = []
    }

    /// 변환 화면(뒤로가기 없음)에 갇히지 않게 닫고 알림을 띄운다. 도면을 저장하지 않으므로 사진도 저장하지 않는다
    private func failScannedPlanSave(_ message: String) {
        scannedPlan = nil
        scanSaveError = message
    }

    // 외부 가져오기는 세부 방식까지 골라야 계속할 수 있다.
    private var canContinue: Bool {
        guard let selectedSourceType, !isCheckingPhotoPermission else { return false }
        return selectedSourceType != .externalImport || importMethod != nil
    }

    // 권한이 허용되면 앨범을 열고, 이전에 거절했으면 설정을 안내한다.
    private func openAlbum() {
        guard !isCheckingPhotoPermission else { return }
        isCheckingPhotoPermission = true
        Task {
            defer { isCheckingPhotoPermission = false }
            let permission = await PermissionService.requestPhotoLibraryPermission()
            guard selectedSourceType == .externalImport, importMethod == .album else { return }

            switch permission {
            case .allowed:
                importedImage = nil
                croppedImage = nil
                showsAlbum = true
            case .deniedNow:
                break
            case .deniedBefore:
                showsPhotoSettings = true
            }
        }
    }

    private func importFile(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            // 파일 앱에서 받은 URL의 접근 권한을 읽기가 끝날 때까지 유지한다.
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let contentType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType
            let isPDF = contentType?.conforms(to: .pdf) == true
                || url.pathExtension.lowercased() == "pdf"
            let image: UIImage?
            if isPDF {
                image = firstPDFPage(at: url)
            } else {
                image = UIImage(data: try Data(contentsOf: url))
            }

            guard let image else {
                showsFileImportError = true
                return
            }
            importedImage = image
            croppedImage = nil
            showsImportCrop = true
        } catch {
            showsFileImportError = true
        }
    }

    // PDF 첫 페이지를 크롭에 사용할 이미지로 변환한다.
    private func firstPDFPage(at url: URL) -> UIImage? {
        guard let document = PDFDocument(url: url),
              let page = document.page(at: 0) else { return nil }
        let size = page.bounds(for: .cropBox).size
        let longestSide = max(size.width, size.height)
        guard size.width > 0, size.height > 0, longestSide.isFinite else { return nil }
        let scale = 2400 / longestSide
        return page.thumbnail(
            of: CGSize(width: size.width * scale, height: size.height * scale),
            for: .cropBox
        )
    }

    private func openCamera() {
        // 카메라가 없는 기기에서는 촬영 화면을 열지 않는다.
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { return }
        isCameraPresented = true
    }
}

// 문구
extension FloorPlanMethodSelectionView {
    private enum Copy {
        // TEMP: Figma에 없는 화면이라 임의로 작성
        static let emptyScan = "스캔된 것이 없어 도면을 저장하지 못했어요. 바닥이나 벽을 비추며 다시 스캔해 주세요."
    }
}

#Preview("평면도 준비") {
    NavigationStack {
        FloorPlanMethodSelectionView(
            fireCase: FireCase(address: "압구정동 462-2", occurredAt: .now)
        )
    }
    .modelContainer(for: FireCase.self, inMemory: true)
}

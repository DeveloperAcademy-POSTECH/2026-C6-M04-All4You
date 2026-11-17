// 도면 저장(내보내기)에서 미리 보고 사진으로 저장할 도면 그림, 그리고 사진 보관함 저장 도우미

import Photos
import SwiftUI
import UIKit

/// 저장 옵션에 맞춰 고친 도면과 사진 핀. 미리보기와 저장이 같은 값을 쓴다
struct FloorPlanExportContent {
    /// 스탬프 표시 옵션을 적용한 도면. 가구는 라벨 설정과 관계없이 유지
    let planData: PlanData
    /// '전체'에서만 표시하는 장소(Room.id)별 사진 앨범 핀
    let pins: [String: PhotoPin]
    /// '북마크'에서만 표시하는 촬영 위치 마커. 방향이 없어도 원형 마커는 표시
    let photoMarkers: [BookmarkPhotoMarker]
    let showsCaptureDirection: Bool
    /// 현재 조사 차수에 사진이 한 장이라도 있는지
    let hasPhotos: Bool
    /// 선택한 표시 방식에 해당하는 사진이 있는지
    let hasVisiblePhotos: Bool
    let hasDirectionalPhotos: Bool
    let showsRoomNames: Bool
    let showsFurnitureLabels: Bool
    
    init(planData original: PlanData, photos: [LoadedPhoto], configuration: FloorPlanSaveConfiguration) {
        var plan = original
        if !configuration.showsStamps {
            plan.markers = []
            plan.wallFixtures = []
        }
        planData = plan
        showsCaptureDirection = configuration.showsCaptureDirection
        showsRoomNames = configuration.showsRoomNames
        showsFurnitureLabels = configuration.showsFurnitureLabels
        hasPhotos = !photos.isEmpty
        
        // 선택한 사진 표시 방식에 해당하는 사진만 사용
        let visiblePhotos: [LoadedPhoto]
        switch configuration.photoDisplay {
        case .hidden: visiblePhotos = []
        case .all: visiblePhotos = photos
        case .bookmarked: visiblePhotos = photos.filter(\.isBookmarked)
        }
        hasVisiblePhotos = !visiblePhotos.isEmpty
        
        // 북마크는 앨범 핀 대신 촬영 위치·방향만 표시
        let markerPhotos = configuration.photoDisplay == .bookmarked ? visiblePhotos : []
        let availableMarkers = markerPhotos
            .sorted { $0.takenAt < $1.takenAt }
            .enumerated()
            .compactMap { index, photo -> BookmarkPhotoMarker? in
                guard var placement = photo.placement(in: plan) else { return nil }
                if let yaw = placement.yaw, !yaw.isFinite { placement.yaw = nil }
                return BookmarkPhotoMarker(id: photo.id, number: index + 1, placement: placement)
            }
        photoMarkers = availableMarkers
        hasDirectionalPhotos = availableMarkers.contains { $0.placement.yaw != nil }
        
        var pins: [String: PhotoPin] = [:]
        if configuration.photoDisplay == .all {
            for room in plan.rooms {
                let roomPhotos = visiblePhotos
                    .filter { $0.roomKey == room.id }
                    .sorted { $0.takenAt > $1.takenAt }
                guard let latest = roomPhotos.first else { continue }
                pins[room.id] = PhotoPin(thumbnail: latest.thumbnail, count: roomPhotos.count)
            }
        }
        self.pins = pins
    }
    
    /// 이름 라벨을 숨길 방. 사진 핀이 있는 방은 핀 캡슐이 이름을 대신하고, 공간 이름을 끄면 모두 숨긴다
    var hiddenLabelRoomIds: Set<String> {
        showsRoomNames ? Set(pins.keys) : Set(planData.rooms.map(\.id))
    }
}

/// 흰 바탕에 도면과 방위표를 그린 2D 그림. 미리보기와 저장 이미지가 같은 그림이다
struct FloorPlanExport2DCanvas: View {
    let content: FloorPlanExportContent
    /// 확대·회전·이동한 시야. nil이면 도면을 화면에 맞춘 처음 시야
    var screen: PlanScreen? = nil
    
    static func fitScreen(of plan: PlanData, in size: CGSize) -> PlanScreen {
        PlanScreen(plan: plan, in: size, fill: Layout.planFill)
    }
    
    var body: some View {
        GeometryReader { proxy in
            let screen = screen ?? Self.fitScreen(of: content.planData, in: proxy.size)
            let compassScale = min(proxy.size.width / Layout.compassReferenceWidth,
                                   proxy.size.height / Layout.compassReferenceHeight)
            // 도면 수정처럼 확대·축소에 맞춰 라벨 크기를 바꾸고, 작은 화면(미리보기)에서는 도면 크기에 맞게 더 줄인다
            let labelFactor = min(1, min(proxy.size.width / Layout.labelReferenceWidth, proxy.size.height / Layout.labelReferenceHeight))
            Plan2DView(planData: content.planData, screen: screen, hiddenLabelRoomIds: content.hiddenLabelRoomIds, scalesLabels: true, labelScaleFactor: labelFactor, showsStampKinds: false, showsFurnitureLabels: content.showsFurnitureLabels)
                .overlay(alignment: .topLeading) {
                    PhotoPinLayer(planData: content.planData, screen: screen, pins: content.pins, selectedRoomID: nil, onTapRoom: { _ in })
                        .allowsHitTesting(false)
                }
                .overlay(alignment: .topLeading) {
                    if !content.photoMarkers.isEmpty {
                        BookmarkPhotoMarkerLayer(markers: content.photoMarkers, screen: screen, showsDirection: content.showsCaptureDirection, style: .compact, scalesMarkers: true, markerScaleFactor: labelFactor)
                            .allowsHitTesting(false)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    // 도면 회전까지 더해 실제 화면에서 보이는 북쪽 방향으로 저장
                    CompassView(northAngle: .radians((content.planData.northAngle ?? 0) + screen.rotation))
                        .scaleEffect(compassScale)
                        .frame(width: Layout.compassSize * compassScale,
                               height: Layout.compassSize * compassScale)
                        .padding(.top, proxy.size.height * Layout.compassInsetRatio)
                        .padding(.trailing, proxy.size.width * Layout.compassInsetRatio)
                        .allowsHitTesting(false)
                }
        }
        .background(.white)
    }
    
    private enum Layout {
        /// 오른쪽 위 방위표와 도면이 겹치지 않도록 남겨 둘 여백을 제외한 도면 크기
        static let planFill = 0.68
        /// 라벨이 도면 수정 화면과 같은 비율로 보이는 화면 크기 (pt). 이보다 작은 화면에서는 비례해 줄인다
        static let labelReferenceWidth: CGFloat = 1200
        static let labelReferenceHeight: CGFloat = 900
        static let compassSize: CGFloat = 104
        static let compassReferenceWidth: CGFloat = 1000
        static let compassReferenceHeight: CGFloat = 750
        static let compassInsetRatio: CGFloat = 0.025
    }
}

/// 2D 미리보기. 도면 수정처럼 핀치로 확대·축소하고 두 손가락으로 돌리고 옮긴다. 저장하는 그림은 여기서 맞춘 시야 그대로다
struct FloorPlanExport2DPreview: View {
    let content: FloorPlanExportContent
    /// 맞춘 시야. nil이면 처음 시야
    @Binding var screen: PlanScreen?
    
    @State private var lastMagnification = 1.0
    @State private var lastRotation = 0.0
    
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            FloorPlanExport2DCanvas(content: content, screen: screen)
                .contentShape(.rect)
                .gesture(zoomGesture(in: size).simultaneously(with: rotateGesture(in: size)))
                .gesture(TwoFingerPanGesture { location, previous in
                    screen = current(in: size).moved(by: CGSize(width: location.x - previous.x, height: location.y - previous.y))
                })
                .overlay(alignment: .bottomTrailing) {
                    // 저장 그림에는 들어가지 않는다 (저장은 FloorPlanExport2DCanvas만 그린다)
                    if screen != nil {
                        ResetViewButton {
                            withAnimation(.easeInOut(duration: Layout.resetDuration)) {
                                screen = nil
                            }
                        }
                        .padding(Layout.resetInset)
                        .transition(.opacity)
                    }
                }
        }
    }
    
    private func current(in size: CGSize) -> PlanScreen {
        screen ?? FloorPlanExport2DCanvas.fitScreen(of: content.planData, in: size)
    }
    
    /// 두 손가락 사이를 기준으로 확대·축소한다
    private func zoomGesture(in size: CGSize) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let factor = value.magnification / lastMagnification
                lastMagnification = value.magnification
                screen = current(in: size).zoomed(by: factor, around: value.startLocation)
            }
            .onEnded { _ in
                lastMagnification = 1
            }
    }
    
    /// 두 손가락이 비틀린 만큼 돌린다. 손을 떼면 가로·세로 방향 가까이면 그 방향에 붙인다
    private func rotateGesture(in size: CGSize) -> some Gesture {
        RotateGesture()
            .onChanged { value in
                // 두 손가락이 정확히 세로·가로가 되는 순간 시스템이 NaN을 줄 때가 있다. 그 값을 넣으면 도면이 사라지므로 건너뛴다
                let radians = value.rotation.radians
                guard radians.isFinite else { return }
                let delta = radians - lastRotation
                lastRotation = radians
                screen = current(in: size).rotated(by: delta, around: value.startLocation)
            }
            .onEnded { _ in
                lastRotation = 0
                withAnimation(.easeOut(duration: Layout.settleDuration)) {
                    screen = current(in: size).settled(around: CGPoint(x: size.width / 2, y: size.height / 2))
                }
            }
    }
    
    private enum Layout {
        static let resetInset: CGFloat = 16
        static let resetDuration = 0.3
        static let settleDuration = 0.15
    }
}

/// 내보내기 이미지 만들기와 사진 보관함 저장
@MainActor
enum FloorPlanExporter {
    /// 저장하는 2D 이미지의 긴 변 (px)
    private static let imageLongEdge: CGFloat = 3200
    
    /// 2D 그림을 이미지로 그린다. 미리보기와 같은 크기·같은 시야(screen)로 그려서 본 그대로 저장하고, 해상도만 높인다
    static func render2D(_ content: FloorPlanExportContent, screen: PlanScreen?, size: CGSize) -> UIImage? {
        guard size.width > 0, size.height > 0 else { return nil }
        let renderer = ImageRenderer(content: FloorPlanExport2DCanvas(content: content, screen: screen).frame(width: size.width, height: size.height))
        renderer.scale = imageLongEdge / max(size.width, size.height)
        return renderer.uiImage
    }
    
    /// 화면에 보이는 영역(전역 좌표)을 그대로 찍는다. 3D 장면은 이미지로 그리는 기본 방법이 없어 화면을 찍는다
    static func captureScreen(in globalFrame: CGRect) -> UIImage? {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = window.screen.scale
        return UIGraphicsImageRenderer(bounds: globalFrame, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
    }
    
    /// 이미지를 사진 보관함에 저장한다. 사진 접근을 거절했으면 에러
    static func saveToPhotoLibrary(_ image: UIImage) async throws {
        guard await PermissionService.requestPhotoLibraryPermission() == .allowed else {
            throw ExportError.photoAccessDenied
        }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
    }
    
    enum ExportError: LocalizedError {
        case photoAccessDenied
        case imageFailed
        
        var errorDescription: String? {
            switch self {
            case .photoAccessDenied: "설정에서 사진 접근을 허용해 주세요"
            case .imageFailed: "도면 이미지를 만들지 못했어요"
            }
        }
    }
}

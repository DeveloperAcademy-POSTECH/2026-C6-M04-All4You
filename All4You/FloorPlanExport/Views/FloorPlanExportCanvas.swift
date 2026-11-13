// 도면 저장(내보내기)에서 미리 보고 사진으로 저장할 도면 그림, 그리고 사진 보관함 저장 도우미

import Photos
import SwiftUI
import UIKit

/// 저장 옵션에 맞춰 고친 도면과 사진 핀. 미리보기와 저장이 같은 값을 쓴다
struct FloorPlanExportContent {
    /// 가구·스탬프를 끈 옵션이면 그 칸을 비운 도면
    let planData: PlanData
    /// 장소(Room.id)별 사진 핀. 사진 표시를 끄면 비어 있다
    let pins: [String: PhotoPin]
    let showsRoomNames: Bool

    init(planData original: PlanData, photos: [LoadedPhoto], configuration: FloorPlanSaveConfiguration) {
        var plan = original
        if !configuration.showsFurniture {
            plan.furniture = nil
        }
        if !configuration.showsStamps {
            plan.markers = []
            plan.wallFixtures = []
        }
        planData = plan
        showsRoomNames = configuration.showsRoomNames

        // 장소마다 가장 최근 사진과 사진 수 (도면 탭의 사진 핀과 같은 규칙)
        var pins: [String: PhotoPin] = [:]
        if configuration.photoDisplay != .hidden {
            for room in plan.rooms {
                let roomPhotos = photos
                    .filter { $0.roomKey == room.id && (configuration.photoDisplay == .all || $0.isBookmarked) }
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

/// 흰 바탕에 도면을 가운데 맞춰 그린 2D 그림. 미리보기와 저장 이미지가 같은 그림이다
struct FloorPlanExport2DCanvas: View {
    let content: FloorPlanExportContent

    var body: some View {
        GeometryReader { proxy in
            let screen = PlanScreen(plan: content.planData, in: proxy.size, fill: Layout.planFill)
            Plan2DView(planData: content.planData, screen: screen, hiddenLabelRoomIds: content.hiddenLabelRoomIds, showsStampKinds: false)
                .overlay(alignment: .topLeading) {
                    PhotoPinLayer(planData: content.planData, screen: screen, pins: content.pins, selectedRoomID: nil, onTapRoom: { _ in })
                        .allowsHitTesting(false)
                }
        }
        .background(.white)
    }

    private enum Layout {
        /// 그림에서 도면이 차지하는 몫
        static let planFill = 0.85
    }
}

/// 내보내기 이미지 만들기와 사진 보관함 저장
@MainActor
enum FloorPlanExporter {
    /// 저장하는 2D 이미지 크기 (pt). 화면 배율(2배)을 곱한 픽셀로 저장된다
    private static let imageSize = CGSize(width: 1600, height: 1200)
    private static let imageScale: CGFloat = 2

    /// 2D 그림을 이미지로 그린다
    static func render2D(_ content: FloorPlanExportContent) -> UIImage? {
        let renderer = ImageRenderer(content: FloorPlanExport2DCanvas(content: content).frame(width: imageSize.width, height: imageSize.height))
        renderer.scale = imageScale
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

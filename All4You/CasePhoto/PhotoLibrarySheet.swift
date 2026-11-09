//
//  PhotoLibrarySheet.swift
//  All4You
//
//  Created by SIA on 11/9/26.
//

// "사진 불러오기"로 뜨는 시트. 사진 보관함의 사진을 찍은 날별로 보여 주고 여러 장을 골라 가져온다
// 애플 기본 사진 선택기(PhotosPicker)는 Figma처럼 왼쪽에 날짜 제목을 둘 수 없어 사진 보관함을 직접 읽는다.
// 권한은 시트를 띄우기 전에 메인 화면(CaseMainView)이 확인한다

import Photos
import SwiftUI

/// 보관함에서 가져온 사진 한 장
struct LibraryPhoto {
    let image: UIImage
    let thumbnail: UIImage
    let takenAt: Date
}

/// 사진 보관함 사진을 여러 장 고르는 시트. 체크를 누르면 고른 사진을 불러와 넘긴다.
/// 사진을 하나씩 누르거나, 사진 위에서 옆으로 밀기 시작해 훑어 여러 장을 한 번에 고르거나, 왼쪽 날짜를 눌러 그날 찍은 사진을 모두 고른다
struct PhotoLibrarySheet: View {
    let onConfirm: ([LibraryPhoto]) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var sections: [PhotoDateSection<PHAsset>] = []
    /// 보관함 사진 id를 화면에 놓인 순서대로. 훑어 고를 때 처음 사진~지금 사진 사이를 고르는 데 쓴다
    @State private var orderedIDs: [String] = []
    @State private var indexByID: [String: Int] = [:]
    /// 고른 사진 (고른 순서)
    @State private var selectedIDs: [String] = []
    /// 화면에 그려진 사진 칸의 자리 (사진 목록 기준 좌표). 손가락 아래 사진을 찾는 데 쓴다
    @State private var tileFrames: [String: CGRect] = [:]
    /// 훑어 고르는 중이면 그 상태, 아니면 nil
    @State private var dragSelection: DragSelection?
    @State private var isLoading = false
    @State private var showsLoadError = false
    @State private var imageManager = PHCachingImageManager()

    /// 훑어 고르기 한 번의 상태
    private struct DragSelection {
        /// 처음 손가락을 댄 사진의 순서
        let anchorIndex: Int
        /// 처음 사진이 이미 골라져 있었으면 훑는 사진을 빼고, 아니면 더한다
        let isDeselecting: Bool
        /// 훑기 전에 골라져 있던 사진
        let baseSelection: [String]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Layout.tileSpacing) {
                    ForEach(sections) { section in
                        dayRow(section)
                    }
                }
                .padding(.vertical)
                .coordinateSpace(.named(Layout.gridSpace))
                .gesture(
                    HorizontalStartPanGesture(coordinateSpace: .named(Layout.gridSpace)) { location in
                        dragSelect(at: location)
                    } onEnded: {
                        dragSelection = nil
                    }
                )
            }
            // 훑어 고르는 동안은 위아래로 움직여도 목록이 따라 움직이지 않게 한다
            .scrollDisabled(dragSelection != nil)
            .overlay {
                if sections.isEmpty {
                    ContentUnavailableView(Copy.emptyTitle, systemImage: "photo.on.rectangle")
                }
            }
            .navigationTitle(Copy.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Copy.close, systemImage: "xmark", role: .close) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    // 고른 사진이 있을 때만 주황으로 채워진다
                    Button(Copy.confirm, systemImage: "checkmark", role: .confirm, action: loadSelectedPhotos)
                        .tint(.brand500)
                        .disabled(selectedIDs.isEmpty || isLoading)
                }
            }
            .overlay {
                if isLoading {
                    ProgressView(Copy.loading)
                        .padding()
                        .background(.regularMaterial, in: .rect(cornerRadius: Layout.loadingCornerRadius))
                }
            }
            .alert(Copy.loadErrorTitle, isPresented: $showsLoadError) {
                Button(Copy.ok, role: .cancel) {}
            }
        }
        .task {
            sections = Self.fetchSections()
            orderedIDs = sections.flatMap { $0.items.map(\.localIdentifier) }
            indexByID = Dictionary(uniqueKeysWithValues: orderedIDs.enumerated().map { ($1, $0) })
        }
    }
}

// 서브 뷰
extension PhotoLibrarySheet {
    /// 왼쪽에 "2026년 10월 9일", 오른쪽에 그날 사진 3열. 사진 칸은 남은 가로 폭을 꽉 채운다
    // TEMP: Figma는 달 단위지만 현장 조사일 단위로 고르기 쉽게 하루 단위로 묶음 — 디자인 반영 필요
    private func dayRow(_ section: PhotoDateSection<PHAsset>) -> some View {
        HStack(alignment: .top, spacing: Layout.dateSpacing) {
            dateButton(section)
            LazyVGrid(columns: Layout.columns, spacing: Layout.tileSpacing) {
                ForEach(section.items, id: \.localIdentifier) { asset in
                    tile(asset)
                }
            }
        }
        .padding(.horizontal, Layout.horizontalPadding)
    }

    /// 누르면 그날 찍은 사진을 모두 고른다. 이미 모두 골라져 있으면 모두 뺀다
    private func dateButton(_ section: PhotoDateSection<PHAsset>) -> some View {
        let ids = section.items.map(\.localIdentifier)
        let isAllSelected = ids.allSatisfy { selectedIDs.contains($0) }
        return Button {
            toggleAll(ids, isAllSelected: isAllSelected)
        } label: {
            Text(section.startDate, format: .dateTime.year().month().day())
                .font(isAllSelected ? AppTypography.subheadlineEmphasized : AppTypography.subheadline)
                .foregroundStyle(isAllSelected ? AnyShapeStyle(.brand500) : AnyShapeStyle(.secondary))
                .multilineTextAlignment(.trailing)
                .frame(width: Layout.dateWidth, alignment: .trailing)
                .padding(.top, Layout.dateTopPadding)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint(isAllSelected ? Copy.deselectDayHint : Copy.selectDayHint)
    }

    /// 사진 한 칸. 한 장이라도 고르면 고르지 않은 사진은 흐려진다
    private func tile(_ asset: PHAsset) -> some View {
        let isSelected = selectedIDs.contains(asset.localIdentifier)
        let isDimmed = !selectedIDs.isEmpty && !isSelected
        return Button {
            toggle(asset.localIdentifier)
        } label: {
            LibraryAssetThumbnail(asset: asset, imageManager: imageManager)
                .opacity(isDimmed ? Layout.dimmedOpacity : 1)
        }
        .buttonStyle(.plain)
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .named(Layout.gridSpace))
        } action: { frame in
            tileFrames[asset.localIdentifier] = frame
        }
        .accessibilityLabel(Text(asset.creationDate ?? .now, format: .dateTime.year().month().day()))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// 고르기
extension PhotoLibrarySheet {
    private func toggle(_ id: String) {
        if let index = selectedIDs.firstIndex(of: id) {
            selectedIDs.remove(at: index)
        } else {
            selectedIDs.append(id)
        }
    }

    private func toggleAll(_ ids: [String], isAllSelected: Bool) {
        if isAllSelected {
            selectedIDs.removeAll { ids.contains($0) }
        } else {
            selectedIDs += ids.filter { !selectedIDs.contains($0) }
        }
    }

    /// 손가락 아래 사진까지 훑은 범위를 고르거나 뺀다. 사진 사이 틈에 있으면 그대로 둔다
    private func dragSelect(at location: CGPoint) {
        guard let id = tileFrames.first(where: { $0.value.contains(location) })?.key,
              let index = indexByID[id] else { return }
        if dragSelection == nil {
            dragSelection = DragSelection(
                anchorIndex: index,
                isDeselecting: selectedIDs.contains(id),
                baseSelection: selectedIDs
            )
        }
        guard let dragSelection else { return }
        let range = min(dragSelection.anchorIndex, index)...max(dragSelection.anchorIndex, index)
        let rangeIDs = orderedIDs[range]
        if dragSelection.isDeselecting {
            selectedIDs = dragSelection.baseSelection.filter { !rangeIDs.contains($0) }
        } else {
            selectedIDs = dragSelection.baseSelection + rangeIDs.filter { !dragSelection.baseSelection.contains($0) }
        }
    }
}

// 불러오기
extension PhotoLibrarySheet {
    /// 보관함 사진을 최신순으로 읽어 찍은 날별로 묶는다
    private static func fetchSections() -> [PhotoDateSection<PHAsset>] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let result = PHAsset.fetchAssets(with: .image, options: options)
        var assets: [PHAsset] = []
        assets.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return PhotoDateSection<PHAsset>.group(assets, by: .day) { $0.creationDate ?? .distantPast }
    }

    /// 고른 사진을 고른 순서대로 불러와 넘기고 시트를 닫는다. 한 장도 못 불러오면 알림을 띄운다
    private func loadSelectedPhotos() {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: selectedIDs, options: nil)
        var assetByID: [String: PHAsset] = [:]
        assets.enumerateObjects { asset, _, _ in
            assetByID[asset.localIdentifier] = asset
        }
        let orderedAssets = selectedIDs.compactMap { assetByID[$0] }
        isLoading = true
        Task {
            var photos: [LibraryPhoto] = []
            for asset in orderedAssets {
                guard let image = await Self.requestImage(for: asset) else { continue }
                let thumbnail = await Task.detached { EvidencePhoto.makeThumbnail(from: image) }.value
                photos.append(LibraryPhoto(image: image, thumbnail: thumbnail, takenAt: asset.creationDate ?? .now))
            }
            isLoading = false
            guard !photos.isEmpty else {
                showsLoadError = true
                return
            }
            onConfirm(photos)
            dismiss()
        }
    }

    /// 증거 사진으로 쓸 만큼 큰 사진을 불러온다. iCloud에만 있는 사진은 내려받는다
    private static func requestImage(for asset: PHAsset) async -> UIImage? {
        let options = PHImageRequestOptions()
        // 가장 좋은 화질 한 번만 답이 오게 해서 continuation을 한 번만 부른다
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: Layout.importSize,
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}

/// 사진 불러오기 시트 크기. Figma처럼 화면 가로의 약 82%, 세로의 90%를 쓴다.
/// 기본 크기(.page)는 종이 한 장 크기라 큰 iPad에서 화면이 많이 남는다
struct PhotoLibrarySheetSizing: PresentationSizing {
    /// 시트를 띄우는 화면의 크기
    let containerSize: CGSize

    func proposedSize(for root: PresentationSizingRoot, context: PresentationSizingContext) -> ProposedViewSize {
        // 화면 크기를 아직 못 쟀으면 종이 한 장 크기(.page)로 띄운다. .unspecified를 넘기면 내용 최소 크기로 아주 작게 뜬다
        guard containerSize.width > 0, containerSize.height > 0 else {
            return PagePresentationSizing.page.proposedSize(for: root, context: context)
        }
        return ProposedViewSize(
            width: containerSize.width * Self.widthRatio,
            height: containerSize.height * Self.heightRatio
        )
    }

    private static let widthRatio: CGFloat = 0.82
    private static let heightRatio: CGFloat = 0.9
}

/// 옆으로 밀기 시작할 때만 잡히는 끌기. 위아래로 밀기 시작하면 잡히지 않아 목록은 평소처럼 넘어간다.
/// SwiftUI 끌기는 넘기기(스크롤)와 겹쳐서 시작 방향을 볼 수 없어 UIKit 끌기를 쓴다
private struct HorizontalStartPanGesture: UIGestureRecognizerRepresentable {
    let coordinateSpace: NamedCoordinateSpace
    /// 손가락 위치 (coordinateSpace 기준)
    let onChanged: (CGPoint) -> Void
    let onEnded: () -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let recognizer = UIPanGestureRecognizer()
        recognizer.delegate = context.coordinator
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        switch recognizer.state {
        case .began, .changed:
            onChanged(context.converter.location(in: coordinateSpace))
        case .ended, .cancelled, .failed:
            onEnded()
        default:
            break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        /// 가로로 더 빠르게 밀 때만 시작한다
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y)
        }
    }
}

/// 보관함 사진 한 칸의 작은 그림. 칸이 보일 때 불러온다
private struct LibraryAssetThumbnail: View {
    let asset: PHAsset
    let imageManager: PHCachingImageManager

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?

    var body: some View {
        Color.gray100
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipped()
            .task(id: asset.localIdentifier) {
                image = await loadThumbnail()
            }
    }

    private func loadThumbnail() async -> UIImage? {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        let length = PhotoLibrarySheet.Layout.thumbnailLength * displayScale
        return await withCheckedContinuation { continuation in
            imageManager.requestImage(
                for: asset,
                targetSize: CGSize(width: length, height: length),
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}

// 크기
extension PhotoLibrarySheet {
    fileprivate enum Layout {
        static let columns = Array(repeating: GridItem(.flexible(), spacing: tileSpacing), count: 3)
        static let tileSpacing: CGFloat = 4
        static let horizontalPadding: CGFloat = 16
        static let dateWidth: CGFloat = 130
        static let dateSpacing: CGFloat = 16
        static let dateTopPadding: CGFloat = 12
        static let dimmedOpacity: CGFloat = 0.4
        static let loadingCornerRadius: CGFloat = 12
        static let thumbnailLength: CGFloat = 400
        /// 사진 칸 자리를 재는 좌표 이름
        static let gridSpace = "PhotoLibrarySheet.grid"
        /// 불러올 사진의 최대 크기 (px). 원본 그대로는 메모리를 너무 많이 써서 줄여 불러온다
        static let importSize = CGSize(width: 2400, height: 2400)
    }
}

// 문구
extension PhotoLibrarySheet {
    private enum Copy {
        static let title = "사진"
        static let close = "닫기"
        static let confirm = "선택 완료"
        static let loading = "사진 불러오는 중"
        static let selectDayHint = "이날 찍은 사진을 모두 선택합니다"
        static let deselectDayHint = "이날 찍은 사진을 모두 선택 해제합니다"
        // TEMP: Figma에 빈 보관함·불러오기 실패 화면이 없어 임의로 작성한 문구
        static let emptyTitle = "불러올 사진이 없어요"
        static let loadErrorTitle = "사진을 불러오지 못했어요"
        static let ok = "확인"
    }
}

#Preview {
    PhotoLibrarySheet(onConfirm: { _ in })
}

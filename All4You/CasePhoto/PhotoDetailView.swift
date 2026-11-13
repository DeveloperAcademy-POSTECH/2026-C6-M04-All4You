// 사진 한 장을 크게 보는 화면. 북마크·마크업·삭제를 하고, 옆으로 넘기거나 아래 띠에서 다른 사진을 고른다

import SwiftUI

/// 사진 보기를 띄울 때 넘기는 값. 넘겨 볼 사진 묶음(순서대로)과 처음 보여 줄 사진
struct PhotoViewerContext: Identifiable {
    let id = UUID()
    let photoIDs: [UUID]
    let initialID: UUID
}

/// 사진을 크게 보여 주고 북마크·마크업·삭제를 하는 화면
struct PhotoDetailView: View {
    let store: PhotoStore
    let context: PhotoViewerContext
    let onClose: () -> Void
    
    @State private var currentID: UUID?
    @State private var isDeleteAlertShown = false
    @State private var isMarkupShown = false
    
    init(store: PhotoStore, context: PhotoViewerContext, onClose: @escaping () -> Void) {
        self.store = store
        self.context = context
        self.onClose = onClose
        _currentID = State(initialValue: context.initialID)
    }
    
    /// 묶음 중 아직 남아 있는 사진. 지운 사진은 저장소에서 사라져 여기서도 빠진다
    private var photos: [LoadedPhoto] {
        context.photoIDs.compactMap(store.photo(id:))
    }
    
    private var currentPhoto: LoadedPhoto? {
        currentID.flatMap(store.photo(id:))
    }
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            pages
        }
        .overlay(alignment: .top) {
            topBar
        }
        .overlay(alignment: .bottom) {
            PhotoThumbnailStrip(photos: photos, selectedID: currentID) { id in
                currentID = id
            }
        }
        .statusBarHidden()
        .alert(Copy.deleteTitle, isPresented: $isDeleteAlertShown) {
            Button(Copy.cancel, role: .cancel) {}
            Button(Copy.delete, role: .destructive, action: deleteCurrentPhoto)
        } message: {
            Text(Copy.deleteMessage)
        }
        .fullScreenCover(isPresented: $isMarkupShown) {
            if let currentPhoto {
                PhotoMarkupView(image: currentPhoto.markupBaseImage, initialDrawingData: currentPhoto.markupDrawingData) {
                    isMarkupShown = false
                } onSave: { image, thumbnail, drawingData in
                    store.replaceImage(id: currentPhoto.id, with: image, thumbnail: thumbnail, drawingData: drawingData)
                    isMarkupShown = false
                }
            }
        }
    }
}

// 서브 뷰
extension PhotoDetailView {
    
    /// 옆으로 넘기고 확대할 수 있는 사진들
    private var pages: some View {
        TabView(selection: $currentID) {
            ForEach(photos) { photo in
                ZoomablePhotoView(
                    image: photo.image,
                    isSelected: currentID == photo.id
                )
                .tag(Optional(photo.id))
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea()
    }
    
    
    /// 왼쪽 뒤로가기·북마크, 가운데 촬영 날짜,
    /// 오른쪽 마크업·삭제
    private var topBar: some View {
        HStack(spacing: Layout.buttonSpacing) {
            
            // 뒤로가기
            glassToolbarButton(
                title: Copy.back,
                systemImage: "chevron.left",
                action: onClose
            )
            
            // 북마크
            if let currentPhoto {
                glassToolbarButton(
                    title: currentPhoto.isBookmarked
                    ? Copy.removeBookmark
                    : Copy.addBookmark,
                    systemImage: currentPhoto.isBookmarked
                    ? "bookmark.fill"
                    : "bookmark"
                ) {
                    store.toggleBookmark(id: currentPhoto.id)
                }
            }
            
            Spacer()
            
            // 마크업
            glassToolbarButton(
                title: Copy.markup,
                systemImage: "pencil.tip.crop.circle"
            ) {
                isMarkupShown = true
            }
            
            // 삭제
            glassToolbarButton(
                title: Copy.delete,
                systemImage: "trash"
            ) {
                isDeleteAlertShown = true
            }
        }
        .overlay {
            if let currentPhoto {
                dateLabel(currentPhoto.takenAt)
            }
        }
        .padding(Layout.edgePadding)
    }
    
    /// 사진 상세 화면 공통 Liquid Glass 버튼
    private func glassToolbarButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(AppTypography.headlineEmphasized)
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(
            .regular.interactive(),
            in: .circle
        )
        .accessibilityLabel(title)
    }
    
    /// 촬영 날짜 및 시간
    private func dateLabel(_ date: Date) -> some View {
        VStack(spacing: 0) {
            Text(
                date,
                format: .dateTime.month().day()
            )
            .font(AppTypography.subheadlineEmphasized)
            .foregroundStyle(.primary)
            
            Text(
                date,
                format: .dateTime.hour().minute()
            )
            .font(AppTypography.label)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Layout.datePadding)
        .padding(.vertical, Layout.dateVerticalPadding)
        .glassEffect(
            .regular,
            in: .capsule
        )
    }
}

/// 손가락 위치를 기준으로 확대·축소하는 사진 뷰
private struct ZoomablePhotoView: UIViewRepresentable {
    let image: UIImage
    let isSelected: Bool
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 5
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.backgroundColor = .clear
        
        // 기본 크기에서는 기존 TabView의 페이지 넘기기 유지
        scrollView.panGestureRecognizer.isEnabled = false
        
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        
        scrollView.addSubview(imageView)
        
        context.coordinator.imageView = imageView
        context.coordinator.currentImage = image
        context.coordinator.isSelected = isSelected
        
        // 더블 탭 위치를 기준으로 확대
        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        
        scrollView.addGestureRecognizer(doubleTap)
        
        return scrollView
    }
    
    func updateUIView(
        _ scrollView: UIScrollView,
        context: Context
    ) {
        let coordinator = context.coordinator
        
        if coordinator.currentImage !== image {
            coordinator.currentImage = image
            coordinator.imageView?.image = image
            coordinator.previousSize = .zero
            scrollView.setZoomScale(1, animated: false)
        }
        
        if coordinator.isSelected != isSelected {
            coordinator.isSelected = isSelected
            
            if !isSelected {
                scrollView.setZoomScale(1, animated: false)
                coordinator.centerImage(in: scrollView)
            }
        }
        
        // 화면 크기가 정해진 뒤 사진 배치
        DispatchQueue.main.async { [weak scrollView] in
            guard let scrollView else { return }
            coordinator.layoutImage(in: scrollView)
        }
    }
    
    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?
        
        var currentImage: UIImage?
        var isSelected = false
        var previousSize: CGSize = .zero
        
        func viewForZooming(
            in scrollView: UIScrollView
        ) -> UIView? {
            imageView
        }
        
        func scrollViewDidZoom(
            _ scrollView: UIScrollView
        ) {
            centerImage(in: scrollView)
            
            // 확대된 경우에만 사진 드래그 허용
            scrollView.panGestureRecognizer.isEnabled =
            scrollView.zoomScale > 1.01
        }
        
        func layoutImage(in scrollView: UIScrollView) {
            let size = scrollView.bounds.size
            
            guard size.width > 0,
                  size.height > 0,
                  let imageView,
                  let image = currentImage,
                  image.size.width > 0,
                  image.size.height > 0
            else { return }
            
            guard previousSize != size else { return }
            
            previousSize = size
            
            let ratio = min(
                size.width / image.size.width,
                size.height / image.size.height
            )
            
            let fittedSize = CGSize(
                width: image.size.width * ratio,
                height: image.size.height * ratio
            )
            
            scrollView.setZoomScale(1, animated: false)
            
            imageView.frame = CGRect(
                origin: .zero,
                size: fittedSize
            )
            
            scrollView.contentSize = fittedSize
            
            centerImage(in: scrollView)
        }
        
        func centerImage(in scrollView: UIScrollView) {
            guard let imageView else { return }
            
            let bounds = scrollView.bounds.size
            
            let offsetX = max(
                (bounds.width - scrollView.contentSize.width) / 2,
                0
            )
            
            let offsetY = max(
                (bounds.height - scrollView.contentSize.height) / 2,
                0
            )
            
            imageView.center = CGPoint(
                x: scrollView.contentSize.width / 2 + offsetX,
                y: scrollView.contentSize.height / 2 + offsetY
            )
        }
        
        @objc func handleDoubleTap(
            _ gesture: UITapGestureRecognizer
        ) {
            guard let scrollView = gesture.view as? UIScrollView,
                  let imageView else { return }
            
            if scrollView.zoomScale > 1 {
                scrollView.setZoomScale(1, animated: true)
                return
            }
            
            let point = gesture.location(in: imageView)
            let targetScale: CGFloat = 2
            
            let zoomRect = CGRect(
                x: point.x - imageView.bounds.width / (targetScale * 2),
                y: point.y - imageView.bounds.height / (targetScale * 2),
                width: imageView.bounds.width / targetScale,
                height: imageView.bounds.height / targetScale
            )
            
            scrollView.zoom(
                to: zoomRect,
                animated: true
            )
        }
    }
}



// 삭제
extension PhotoDetailView {
    /// 지운 뒤에는 다음 사진(없으면 앞 사진)을 보여 주고, 남은 사진이 없으면 화면을 닫는다
    private func deleteCurrentPhoto() {
        guard let currentID else { return }
        let remaining = photos.map(\.id)
        let index = remaining.firstIndex(of: currentID) ?? 0
        let neighbors = remaining.filter { $0 != currentID }
        store.delete(id: currentID)
        guard !neighbors.isEmpty else {
            onClose()
            return
        }
        self.currentID = neighbors[min(index, neighbors.count - 1)]
    }
}

// 크기
extension PhotoDetailView {
    private enum Layout {
        static let edgePadding: CGFloat = 24
        static let buttonSpacing: CGFloat = 12
        static let datePadding: CGFloat = 16
        static let dateVerticalPadding: CGFloat = 4
    }
}

// 문구
extension PhotoDetailView {
    private enum Copy {
        static let back = "뒤로"
        static let addBookmark = "북마크"
        static let removeBookmark = "북마크 해제"
        static let markup = "마크업"
        static let delete = "삭제"
        static let cancel = "취소"
        static let deleteTitle = "사진을 삭제할까요?"
        static let deleteMessage = "삭제한 사진은 복구할 수 없어요"
    }
}

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
    private var photos: [EvidencePhoto] {
        context.photoIDs.compactMap(store.photo(id:))
    }

    private var currentPhoto: EvidencePhoto? {
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
                PhotoMarkupView(image: currentPhoto.image) {
                    isMarkupShown = false
                } onSave: { image, thumbnail in
                    store.replaceImage(id: currentPhoto.id, with: image, thumbnail: thumbnail)
                    isMarkupShown = false
                }
            }
        }
    }
}

// 서브 뷰
extension PhotoDetailView {
    /// 옆으로 밀어 넘기는 사진들
    private var pages: some View {
        TabView(selection: $currentID) {
            ForEach(photos) { photo in
                Image(uiImage: photo.image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .tag(Optional(photo.id))
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea()
    }

    /// 왼쪽 뒤로가기·북마크, 가운데 찍은 날짜, 오른쪽 마크업·삭제
    private var topBar: some View {
        HStack(spacing: Layout.buttonSpacing) {
            GlassCircleButton(title: Copy.back, systemImage: "chevron.left", action: onClose)
            if let currentPhoto {
                GlassCircleButton(
                    title: currentPhoto.isBookmarked ? Copy.removeBookmark : Copy.addBookmark,
                    systemImage: currentPhoto.isBookmarked ? "bookmark.fill" : "bookmark"
                ) {
                    store.toggleBookmark(id: currentPhoto.id)
                }
            }
            Spacer()
            GlassCircleButton(title: Copy.markup, systemImage: "pencil.tip.crop.circle") {
                isMarkupShown = true
            }
            GlassCircleButton(title: Copy.delete, systemImage: "trash") {
                isDeleteAlertShown = true
            }
        }
        // 날짜는 버튼 줄과 상관없이 화면 가운데에 둔다
        .overlay {
            if let currentPhoto {
                dateLabel(currentPhoto.takenAt)
            }
        }
        .padding(Layout.edgePadding)
    }

    /// "10월 9일" 아래 작은 "오후 10:46"
    private func dateLabel(_ date: Date) -> some View {
        VStack(spacing: 0) {
            Text(date, format: .dateTime.month().day())
                .font(AppTypography.subheadlineEmphasized)
            Text(date, format: .dateTime.hour().minute())
                .font(AppTypography.label)
                .foregroundStyle(.white.secondary)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, Layout.datePadding)
        .padding(.vertical, Layout.dateVerticalPadding)
        .glassEffect(in: .capsule)
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

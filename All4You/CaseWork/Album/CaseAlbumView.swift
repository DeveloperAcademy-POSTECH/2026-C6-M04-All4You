//
//  CaseAlbumView.swift
//  All4You
//
//  Created by SIA on 11/9/26.
//

// 사건 작업 메인의 앨범 탭. 전체 보기(장소별 가로 줄)와 장소 하나의 사진 모음, 아래 장소 고르기 막대로 구성된다

import SwiftUI

/// 장소별로 사진을 모아 보는 탭. 사진을 누르면 크게 보는 화면이 뜬다
struct CaseAlbumView: View {
    let photoStore: PhotoStore
    let rooms: [Room]
    /// 사이드바·장소 막대가 함께 보는 고른 줄. .albumOverview면 전체, .album(이름)이면 그 장소
    @Binding var selection: CaseTabSelection
    /// 전체 보기의 "위치 미지정 >"를 누르면 도면 탭에서 위치 미확인 사진 패널을 연다
    let onPlaceUnassigned: () -> Void
    
    @State private var viewerContext: PhotoViewerContext?
    
    var body: some View {
        content
            .overlay(alignment: .bottom) {
                roomPicker
                    .padding(.bottom, Layout.pickerBottomPadding)
            }
            .fullScreenCover(item: $viewerContext) { context in
                PhotoDetailView(store: photoStore, context: context) {
                    viewerContext = nil
                }
            }
    }
    
    @ViewBuilder
    private var content: some View {
        if case .album(let name) = selection {
            RoomAlbumView(
                title: name,
                photos: sortedPhotos(inRoom: roomKey(of: name)),
                onOpenPhoto: openViewer,
                onBack: {
                    withAnimation {
                        selection = .albumOverview
                    }
                }
            )
            // 장소가 바뀌면 "북마크만 보기"를 처음 상태로 돌린다
            .id(name)
        } else {
            overview
        }
    }
}

// 전체 보기
extension CaseAlbumView {
    /// 위치 미지정, 그다음 도면의 장소 순서로 가로 줄을 보여 준다.
    /// 사진이 없는 장소도 줄을 만들어 두어, 어떤 장소가 있는지 먼저 보이게 한다
    private var overview: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                let unassigned = sortedPhotos(inRoom: nil)
                // 위치 미지정 사진이 있을 때만 위치를 정하는 패널로 간다
                overviewSection(
                    title: CaseAlbumView.unassignedName,
                    photos: unassigned,
                    badge: unassigned.isEmpty ? nil : unassigned.count,
                    onOpen: unassigned.isEmpty ? nil : onPlaceUnassigned
                )
                ForEach(rooms) { room in
                    overviewSection(title: room.name, photos: sortedPhotos(inRoom: room.id), badge: nil) {
                        selection = .album(room.name)
                    }
                }
            }
            .padding(.vertical)
            // 아래 장소 막대에 마지막 줄이 가리지 않게 띄운다
            .padding(.bottom, Layout.pickerClearance)
        }
    }
    
    /// "안방 >" 제목과 그 장소 사진의 가로 줄. 사진이 없으면 빈 칸 하나를 둔다. onOpen이 nil이면 제목을 누를 수 없다
    private func overviewSection(title: String, photos: [LoadedPhoto], badge: Int?, onOpen: (() -> Void)?) -> some View {
        VStack(alignment: .leading, spacing: Layout.headerSpacing) {
            Button {
                onOpen?()
            } label: {
                HStack(spacing: Layout.chevronSpacing) {
                    Text(title)
                    Image(systemName: "chevron.right")
                }
                .font(AppTypography.title1Emphasized)
                .foregroundStyle(.primary)
                .overlay(alignment: .bottomTrailing) {
                    if let badge {
                        CountBadge(count: badge)
                            .offset(y: Layout.badgeOffset)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(onOpen == nil)
            .padding(.horizontal, Layout.horizontalPadding)
            
            if photos.isEmpty {
                EmptyAlbumTile()
                    .frame(width: Layout.rowTileSize, height: Layout.rowTileSize)
                    .padding(.horizontal, Layout.horizontalPadding)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: Layout.tileSpacing) {
                        ForEach(photos) { photo in
                            AlbumPhotoTile(photo: photo) {
                                openViewer(photos: photos, initialID: photo.id)
                            }
                            .frame(width: Layout.rowTileSize, height: Layout.rowTileSize)
                        }
                    }
                    .padding(.horizontal, Layout.horizontalPadding)
                }
            }
        }
    }
}

// 장소 고르기 막대
extension CaseAlbumView {
    /// 아래 가운데 유리 캡슐 안의 "전체 · 안방 · 거실 …". 고른 칸은 흰 캡슐로 보인다
    private var roomPicker: some View {
        HStack(spacing: 0) {
            pickerItem(Copy.all, value: .albumOverview)
            ForEach(rooms) { room in
                pickerItem(room.name, value: .album(room.name))
            }
        }
        .padding(Layout.pickerPadding)
        .glassEffect(in: .capsule)
    }
    
    private func pickerItem(_ title: String, value: CaseTabSelection) -> some View {
        let isSelected = selection == value
        return Button {
            withAnimation {
                selection = value
            }
        } label: {
            Text(title)
                .font(AppTypography.headline)
                .foregroundStyle(.primary)
                .padding(.horizontal, Layout.pickerItemPadding)
                .frame(minWidth: Layout.pickerItemMinWidth, minHeight: Layout.pickerItemHeight)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(.background)
                    }
                }
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// 사진 고르기
extension CaseAlbumView {
    /// 사이드바·앨범에서 위치 미지정 줄의 이름
    static let unassignedName = "위치 미지정"
    
    /// 장소 이름을 Room.id로 바꾼다. 위치 미지정이거나 없는 장소면 nil
    // TODO: CaseTabSelection이 이름 대신 Room.id를 들게 되면 없앤다
    private func roomKey(of name: String) -> String? {
        rooms.first { $0.name == name }?.id
    }
    
    /// 장소 사진을 최근에 찍은 것부터
    private func sortedPhotos(inRoom roomKey: String?) -> [LoadedPhoto] {
        photoStore.photos(inRoom: roomKey).sorted { $0.takenAt > $1.takenAt }
    }
    
    private func openViewer(photos: [LoadedPhoto], initialID: UUID) {
        viewerContext = PhotoViewerContext(photoIDs: photos.map(\.id), initialID: initialID)
    }
}

// 크기
extension CaseAlbumView {
    fileprivate enum Layout {
        static let horizontalPadding: CGFloat = 32
        static let sectionSpacing: CGFloat = 32
        static let headerSpacing: CGFloat = 16
        static let chevronSpacing: CGFloat = 6
        static let badgeOffset: CGFloat = 12
        static let tileSpacing: CGFloat = 16
        static let rowTileSize: CGFloat = 227
        /// 아래 장소 막대를 화면 아래에서 띄우는 거리. 다른 화면의 아래 컴포넌트와 같다
        static let pickerBottomPadding = BarLayout.edgeInset
        /// 목록 끝이 장소 막대에 가리지 않게 비우는 높이 (막대 아래 여백 32 + 막대 52 + 위 여백 12)
        static let pickerClearance: CGFloat = 96
        static let pickerPadding: CGFloat = 4
        static let pickerItemPadding: CGFloat = 20
        static let pickerItemMinWidth: CGFloat = 88
        static let pickerItemHeight: CGFloat = 44
    }
}

// 문구
extension CaseAlbumView {
    private enum Copy {
        static let all = "전체"
    }
}

/// 장소 하나의 사진 모음. 큰 제목, "북마크만 보기", 달별 사진 칸으로 구성된다
private struct RoomAlbumView: View {
    let title: String
    let photos: [LoadedPhoto]
    let onOpenPhoto: (_ photos: [LoadedPhoto], _ initialID: UUID) -> Void
    /// 앨범 전체로 돌아간다
    let onBack: () -> Void
    
    @State private var isBookmarkOnly = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Layout.titleSpacing) {
                header
                LazyVGrid(
                    columns: Layout.columns,
                    alignment: .leading,
                    spacing: Layout.tileSpacing,
                    pinnedViews: .sectionHeaders
                ) {
                    if isBookmarkOnly {
                        // 북마크 사진을 앞에 모으고, 나머지는 뒤에서 흐리게 표시
                        ForEach(orderedPhotos) { photo in
                            tile(photo, bookmarkFilterEnabled: true)
                        }
                    } else {
                        // 필터를 끄면 기존 월별 섹션과 촬영 순서로 복귀
                        ForEach(PhotoDateSection<LoadedPhoto>.group(photos, by: .month, date: \.takenAt)) { section in
                            Section {
                                ForEach(section.items) { photo in
                                    tile(photo, bookmarkFilterEnabled: false)
                                }
                            } header: {
                                monthLabel(section.startDate)
                            }
                        }
                    }
                }
                .id(isBookmarkOnly)
                
            }
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.bottom, Layout.pickerClearance)
        }
        .overlay {
            if photos.isEmpty {
                ContentUnavailableView(Copy.emptyTitle, systemImage: "photo.on.rectangle.angled", description: Text(Copy.emptyMessage))
            }
        }
    }
    
    /// 북마크를 먼저 배치하되, 각 그룹 안의 기존 촬영 순서는 유지
    private var orderedPhotos: [LoadedPhoto] {
        let bookmarked = photos.filter { $0.isBookmarked }
        let others = photos.filter { !$0.isBookmarked }
        return bookmarked + others
    }
    
    /// 필터 중 전체 화면 보기에서는 북마크 사진만 넘길 수 있다
    private var visiblePhotos: [LoadedPhoto] {
        isBookmarkOnly ? photos.filter(\.isBookmarked) : photos
    }
    
    private var header: some View {
        HStack(spacing: Layout.backSpacing) {
            // 시스템 뒤로가기를 붙이면 왼쪽 위 사건 뒤로가기와 겹쳐서, 제목 줄에 앨범 전체로 돌아가는 버튼을 둔다
            // TEMP: Figma에 장소 화면의 복귀 버튼이 없어 제목 왼쪽에 임의로 둠 — 디자인이 나오면 맞춘다
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: BarLayout.iconSize, weight: .semibold))
                    .frame(width: BarLayout.controlSize, height: BarLayout.controlSize)
                    // plain 버튼은 그려진 선만 눌려서, 원 전체를 누르는 자리로 잡는다 (iPadOS 26.5에서 안 눌리던 문제)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel(Copy.backToOverview)
            Text(title)
                .font(.largeTitle.bold())
            Spacer()
            Button {
                withAnimation {
                    isBookmarkOnly.toggle()
                }
            } label: {
                HStack(spacing: Layout.toggleSpacing) {
                    Image(systemName: "checkmark")
                        .font(AppTypography.subheadlineEmphasized)
                        .foregroundStyle(isBookmarkOnly ? AnyShapeStyle(.white) : AnyShapeStyle(.tertiary))
                        .frame(width: Layout.toggleSize, height: Layout.toggleSize)
                        .glassEffect(isBookmarkOnly ? .regular.tint(.brand500) : .regular, in: .circle)
                    Text(Copy.bookmarkOnly)
                        .font(AppTypography.title3)
                        .foregroundStyle(.primary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isBookmarkOnly ? .isSelected : [])
        }
        .padding(.top, Layout.titleTopPadding)
    }
    
    /// "2026년 10월" 회색 캡슐. 위에 고정돼도 사진 위에서 읽히도록 바탕을 깐다
    private func monthLabel(_ month: Date) -> some View {
        Text(month, format: .dateTime.year().month())
            .font(AppTypography.subheadline)
            .padding(.horizontal, Layout.monthPadding)
            .padding(.vertical, Layout.monthVerticalPadding)
            .background(.gray100, in: .capsule)
            .padding(.vertical, Layout.monthVerticalPadding)
    }
    
    private func tile(_ photo: LoadedPhoto, bookmarkFilterEnabled: Bool) -> some View {
        let isDimmed = bookmarkFilterEnabled && !photo.isBookmarked
        
        return AlbumPhotoTile(photo: photo) {
            onOpenPhoto(visiblePhotos, photo.id)
        }
        .aspectRatio(1, contentMode: .fit)
        .opacity(isDimmed ? Layout.dimmedOpacity : 1)
        .disabled(isDimmed)
    }
}

// 크기
extension RoomAlbumView {
    private enum Layout {
        static let columns = [GridItem(.adaptive(minimum: 200), spacing: tileSpacing)]
        static let horizontalPadding: CGFloat = 32
        static let titleTopPadding: CGFloat = 8
        static let titleSpacing: CGFloat = 16
        static let tileSpacing: CGFloat = 16
        static let backSpacing: CGFloat = 12
        static let toggleSpacing: CGFloat = 12
        static let toggleSize: CGFloat = 36
        static let monthPadding: CGFloat = 24
        static let monthVerticalPadding: CGFloat = 6
        static let dimmedOpacity: CGFloat = 0.3
        /// 목록 끝이 장소 막대에 가리지 않게 비우는 높이. CaseAlbumView의 pickerClearance와 같은 값
        static let pickerClearance: CGFloat = 96
    }
}

// 문구
extension RoomAlbumView {
    private enum Copy {
        static let bookmarkOnly = "북마크만 보기"
        static let backToOverview = "앨범 전체"
        // TEMP: Figma에 사진이 없는 장소 화면이 없어 임의로 작성한 문구
        static let emptyTitle = "아직 사진이 없어요"
        static let emptyMessage = "위의 사진 추가 버튼으로 촬영하거나, 도면에서 위치 미확인 사진을 이 장소로 옮겨 주세요."
    }
}

/// 사진이 없는 장소 줄에 두는 점선 빈 칸
// TEMP: Figma에 빈 장소 디자인이 없어 임의로 그림 — 팀 확인 필요
private struct EmptyAlbumTile: View {
    var body: some View {
        RoundedRectangle(cornerRadius: Layout.cornerRadius)
            .strokeBorder(.gray200, style: StrokeStyle(lineWidth: Layout.borderWidth, dash: Layout.dash))
            .overlay {
                VStack(spacing: Layout.spacing) {
                    Image(systemName: "photo")
                        .font(AppTypography.title2)
                    Text(Copy.empty)
                        .font(AppTypography.subheadline)
                }
                .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
    }
    
    private enum Layout {
        static let cornerRadius: CGFloat = 16
        static let borderWidth: CGFloat = 2
        static let dash: [CGFloat] = [8, 6]
        static let spacing: CGFloat = 8
    }
    
    private enum Copy {
        static let empty = "사진 없음"
    }
}

/// 둥근 정사각 사진 한 칸. 북마크한 사진은 오른쪽 위에 흰 책갈피가 보인다
private struct AlbumPhotoTile: View {
    let photo: LoadedPhoto
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Color.clear
                .overlay {
                    Image(uiImage: photo.thumbnail)
                        .resizable()
                        .scaledToFill()
                }
                .clipShape(.rect(cornerRadius: Layout.cornerRadius))
                .overlay(alignment: .topTrailing) {
                    if photo.isBookmarked {
                        Image(systemName: "bookmark.fill")
                            .font(AppTypography.title3)
                            .foregroundStyle(.white)
                            .shadow(radius: Layout.iconShadowRadius)
                            .padding(Layout.iconPadding)
                    }
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(photo.takenAt, format: .dateTime.month().day().hour().minute()))
    }
    
    private enum Layout {
        static let cornerRadius: CGFloat = 16
        static let iconPadding: CGFloat = 14
        static let iconShadowRadius: CGFloat = 2
    }
}

#Preview {
    @Previewable @State var selection = CaseTabSelection.albumOverview
    
    CaseAlbumView(
        photoStore: PhotoStore(),
        rooms: DummyFloorPlan.planData.rooms,
        selection: $selection,
        onPlaceUnassigned: {}
    )
}

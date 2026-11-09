// 사건 작업 메인의 도면 탭. 도면(보기 전용)과 사진 핀, 필터 메뉴, 2D/3D 전환,
// 오른쪽 패널(장소 사진 모음 또는 위치 미확인 사진)로 구성된다

import SwiftUI
import UniformTypeIdentifiers

/// 도면을 보고 사진 표시 방식과 2D/3D를 고르는 탭.
/// 사진 핀을 누르면 오른쪽에 그 장소 사진 모음이 열리고, 위치 미확인 사진 패널을 펼치면 사진을 2D 도면의 장소로 끌어다 놓는다
struct FloorPlanTabView: View {
    @Binding var photoFilter: PhotoFilter
    @Binding var dimension: Dimension
    /// 보여 줄 도면. 없으면 회색 자리를 보여 준다
    var planData: PlanData? = nil
    let photoStore: PhotoStore
    /// 위치 미확인 사진 패널을 펼쳤는지
    @Binding var isPlacingPhotos: Bool
    /// 도면에 띄울 저장된 메모. 2D는 도면 위에, 3D는 3D 자리에 핀을 띄운다 (메모 위치를 고르는 동안은 메인의 메모 오버레이가 그린다)
    var memos: [FloorPlanMemo] = []

    /// 2D 도면이 화면에 놓인 배율과 자리. 화면 크기를 알게 되면 만든다
    @State private var screen: PlanScreen?
    /// 오므리는 동안 직전까지 적용한 배율. 바뀐 만큼만 screen에 곱한다
    @State private var lastMagnification = 1.0
    /// 사진 핀을 눌러 고른 장소 (Room.id). 오른쪽에 그 장소 사진 모음이 열린다
    @State private var selectedRoomID: String?
    /// 장소 사진 모음의 확대 버튼을 누르면 띄우는 전체 화면 사진 보기
    @State private var viewerContext: PhotoViewerContext?
    /// 패널에서 끌고 있는 사진 (EvidencePhoto.id)
    @State private var draggingPhotoID: UUID?
    /// 끌고 있는 사진이 지금 손가락 아래에 있는 장소 (Room.id). 이 장소에 미리보기 핀을 띄운다
    @State private var hoveredRoomID: String?
    /// 누른 북마크 번호 핀의 사진 (LoadedPhoto.id). 나머지 도면·핀은 흐려지고 오른쪽에 그 사진이 열린다
    @State private var selectedBookmarkID: UUID?

    /// 도면을 평면으로 볼지 입체로 볼지
    typealias Dimension = PlanDimension

    var body: some View {
        HStack(spacing: 0) {
            floorPlanArea
                .overlay(alignment: .topLeading) {
                    PhotoFilterMenu(filter: $photoFilter)
                        .padding()
                }
                .overlay(alignment: .topTrailing) {
                    // 패널을 닫아도 위치를 정하지 않은 사진이 남아 있으면 언제든 다시 열 수 있게 둔다
                    if !isPlacingPhotos && selectedRoom == nil && selectedBookmark == nil && unassignedCount > 0 {
                        openPanelButton
                            .padding()
                    }
                }
                .overlay(alignment: .bottom) {
                    dimensionPicker
                }
            if isPlacingPhotos {
                Divider()
                UnassignedPhotoPanel(photos: photoStore.unassignedPhotos) {
                    withAnimation {
                        isPlacingPhotos = false
                    }
                } onDragStart: { id in
                    draggingPhotoID = id
                }
                .frame(maxWidth: .infinity)
                .transition(.move(edge: .trailing))
            } else if let selected = selectedBookmark {
                Divider()
                BookmarkPhotoPanel(
                    roomName: selected.photo.roomKey.flatMap { key in planData?.rooms.first { $0.id == key }?.name },
                    number: selected.marker.number,
                    photo: selected.photo
                ) {
                    openBookmarkViewer(initialID: selected.photo.id)
                }
                // 다른 핀을 고르면 사진을 처음부터 보여 준다
                .id(selected.photo.id)
                .frame(maxWidth: .infinity)
                .transition(.move(edge: .trailing))
            } else if let selectedRoom {
                Divider()
                let photos = filteredPhotos(inRoom: selectedRoom.id)
                RoomPhotoPanel(roomName: selectedRoom.name, photos: photos) { id in
                    viewerContext = PhotoViewerContext(photoIDs: photos.map(\.id), initialID: id)
                }
                // 다른 장소를 고르면 큰 사진·스크롤을 처음부터 보여 준다
                .id(selectedRoom.id)
                .frame(maxWidth: .infinity)
                .transition(.move(edge: .trailing))
            }
        }
        .fullScreenCover(item: $viewerContext) { context in
            PhotoDetailView(store: photoStore, context: context) {
                viewerContext = nil
            }
        }
        // 위치 미확인 사진 패널을 열면 장소 선택은 푼다 (오른쪽 패널은 하나만)
        .onChange(of: isPlacingPhotos) { _, isPlacing in
            if isPlacing {
                selectedRoomID = nil
                selectedBookmarkID = nil
            }
        }
    }
}

// 서브 뷰
extension FloorPlanTabView {
    /// 2D는 화면에 맞춰 그리고 두 손가락으로 확대·이동하며, 3D는 돌리고 확대해 볼 수만 있다. 둘 다 고치기는 받지 않는다.
    /// 2D에는 장소별 사진 핀을 겹치고, 위치 미확인 사진을 끌어다 놓으면 놓은 자리의 장소로 옮긴다
    /// 3D에는 사진 핀과 메모 핀을 3D 자리에 띄워, 돌리고 확대해도 따라온다. 사진 핀을 누르면 2D와 같이 장소 사진 모음이 열린다
    @ViewBuilder
    private var floorPlanArea: some View {
        if let planData {
            switch dimension {
            case .twoD:
                GeometryReader { proxy in
                    if let screen {
                        let pins = visiblePins(in: planData)
                        let focusedRoom = selectedBookmark.flatMap { selected in
                            planData.rooms.first { $0.id == selected.photo.roomKey }
                        }
                        // 핀이 있는 장소는 핀 캡슐이 이름 라벨을 대신하므로 도면의 이름 라벨은 숨긴다.
                        // 북마크 핀을 고르면 도면·장소 핀을 흐리게 하고, 그 사진의 장소 라벨만 위에 진하게 다시 그린다
                        Plan2DView(planData: planData, screen: screen, hiddenLabelRoomIds: Set(pins.keys).union(focusedRoom.map { [$0.id] } ?? []))
                            .opacity(selectedBookmark == nil ? 1 : Layout.focusDimmedOpacity)
                        PhotoPinLayer(
                            planData: planData,
                            screen: screen,
                            pins: pins,
                            selectedRoomID: selectedRoomID,
                            onTapRoom: selectRoom
                        )
                        .opacity(selectedBookmark == nil ? 1 : Layout.focusDimmedOpacity)
                        if let focusedRoom {
                            RoomLabelView(name: focusedRoom.name)
                                .position(screen.point(SIMD2(focusedRoom.labelX, focusedRoom.labelY)))
                                .allowsHitTesting(false)
                        }
                        // 북마크 필터: 북마크 사진을 찍은 정확한 자리에 번호 핀 (촬영 방향을 켜면 부채꼴도)
                        if showsBookmarkMarkers {
                            BookmarkPhotoMarkerLayer(
                                markers: bookmarkMarkers(in: planData),
                                screen: screen,
                                showsDirection: photoFilter.showsDirection,
                                selectedID: selectedBookmark?.photo.id,
                                onTap: selectBookmark
                            )
                        }
                        // 저장된 메모 핀도 도면과 같은 screen으로 그려, 확대·이동하거나 사진 모음이 열려 도면이 좁아져도 따라간다
                        FloorPlanMemoPlacementOverlay(
                            planData: planData,
                            memos: memos,
                            isPresented: .constant(false),
                            draft: .constant(nil),
                            onSave: { _ in },
                            onCancel: {},
                            screen: screen
                        )
                    }
                    Color.clear
                        .onAppear { fitPlan(planData, in: proxy.size) }
                        .onChange(of: proxy.size) { _, size in fitPlan(planData, in: size) }
                }
                // 놓는 자리는 GeometryReader 기준 좌표라 screen과 같은 기준이다. 그래서 padding보다 먼저 붙인다
                .onDrop(of: [.plainText], delegate: PhotoDropDelegate(
                    roomAt: { location in
                        guard let screen else { return nil }
                        return planData.room(containing: screen.plan(location))
                    },
                    onHover: { room in
                        guard hoveredRoomID != room?.id else { return }
                        withAnimation(.snappy) {
                            hoveredRoomID = room?.id
                        }
                    },
                    onDrop: dropPhoto
                ))
                // 처음 맞출 때 도면이 위 필터 메뉴·아래 2D/3D 막대와 겹치지 않게 한다
                .padding(.vertical, Layout.overlayInset)
                .background(.white)
                // 옮기거나 확대한 도면이 상단 바 위로 넘쳐 보이지 않게 한다
                .clipped()
                .contentShape(.rect)
                // 도면 빈 곳을 누르면 장소 선택을 풀고 사진 모음을 닫는다. 핀(버튼)을 누른 것은 핀이 먼저 받는다
                .onTapGesture(perform: clearRoomSelection)
                .gesture(zoomGesture)
                .gesture(TwoFingerPanGesture(onChanged: panPlan))
            case .threeD:
                // 고른 것이 없고 누르기·편집 알림을 버리므로 카메라 조작과 핀만 남는다
                FloorPlan3DView(
                    planData: planData,
                    selection: nil,
                    // 도면을 누르면 2D처럼 장소 선택을 풀고 오른쪽 사진 모음을 닫는다. 사진 핀(버튼)은 핀이 먼저 받는다
                    onTap: { _ in clearRoomSelection() },
                    onEdit: { _ in },
                    pins: pins3D(in: planData),
                    pinView: { id in pinView3D(id: id, in: planData) }
                )
            }
        } else {
            Text(Copy.placeholder)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.quaternary)
        }
    }

    /// "위치 미확인 사진 120". 누르면 2D 도면으로 바꾸고 오른쪽에 위치 미확인 사진 패널을 연다
    // TEMP: Figma에 패널을 다시 여는 버튼이 없어 임의로 둠 — 팀 확인 필요
    private var openPanelButton: some View {
        Button {
            dimension = .twoD
            withAnimation {
                isPlacingPhotos = true
            }
        } label: {
            HStack(spacing: Layout.openPanelSpacing) {
                Image(systemName: "photo.badge.exclamationmark")
                Text(Copy.openPanel)
                CountBadge(count: unassignedCount)
            }
            .font(AppTypography.headline)
            .foregroundStyle(.primary)
            .padding(.horizontal, Layout.openPanelPadding)
            .frame(height: Layout.openPanelHeight)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    private var unassignedCount: Int {
        photoStore.unassignedPhotos.count
    }

    private var dimensionPicker: some View {
        DimensionPicker(selection: $dimension)
            .padding()
            // 사진을 끌어다 놓을 수 있는 건 2D 도면뿐이라, 패널을 펼친 동안은 3D로 바꿀 수 없게 한다
            .disabled(isPlacingPhotos)
    }
}

// 장소 선택
extension FloorPlanTabView {
    /// 고른 장소. 필터로 보이는 사진이 없어지면 고르지 않은 것으로 본다
    private var selectedRoom: Room? {
        guard let selectedRoomID, photoFilter.isPhotoVisible, !filteredPhotos(inRoom: selectedRoomID).isEmpty else { return nil }
        return planData?.rooms.first { $0.id == selectedRoomID }
    }

    /// 장소·북마크 선택을 풀어 오른쪽 패널을 닫는다
    private func clearRoomSelection() {
        withAnimation {
            selectedRoomID = nil
            selectedBookmarkID = nil
        }
    }

    private func selectRoom(_ room: Room) {
        withAnimation {
            selectedBookmarkID = nil
            selectedRoomID = room.id
        }
    }

    /// 북마크 번호 핀을 고른다. 같은 핀을 다시 누르면 푼다
    private func selectBookmark(_ id: UUID) {
        withAnimation {
            selectedRoomID = nil
            selectedBookmarkID = selectedBookmarkID == id ? nil : id
        }
    }

    /// 고른 북마크 핀과 그 사진. 필터를 바꾸거나 북마크를 풀어 핀이 사라지면 고르지 않은 것으로 본다
    private var selectedBookmark: (marker: BookmarkPhotoMarker, photo: LoadedPhoto)? {
        guard let selectedBookmarkID, showsBookmarkMarkers, let planData,
              let marker = bookmarkMarkers(in: planData).first(where: { $0.id == selectedBookmarkID }),
              let photo = photoStore.photo(id: selectedBookmarkID) else { return nil }
        return (marker, photo)
    }

    /// 장소 사진 중 필터에 맞는 것을 최근에 찍은 것부터. 북마크를 고르면 북마크한 사진만
    private func filteredPhotos(inRoom roomID: String) -> [LoadedPhoto] {
        photoStore.photos(inRoom: roomID)
            .filter { photoFilter.scope == .all || $0.isBookmarked }
            .sorted { $0.takenAt > $1.takenAt }
    }
}

// 3D 핀
extension FloorPlanTabView {
    /// 사진 핀은 장소 이름 자리에, 메모 핀은 메모를 남긴 자리에 띄운다
    private func pins3D(in planData: PlanData) -> [Plan3DPin] {
        let photoPins = photoPins(in: planData).keys.compactMap { roomID in
            planData.rooms.first { $0.id == roomID }.map { room in
                Plan3DPin(id: Pin3DID.photo + room.id, point: SIMD2(room.labelX, room.labelY), height: Layout.photoPinHeight)
            }
        }
        let memoPins = memos.map { memo in
            Plan3DPin(id: Pin3DID.memo + memo.id.uuidString, point: memo.anchor.point, height: Layout.memoPinHeight)
        }
        return photoPins.sorted { $0.id < $1.id } + memoPins
    }

    /// 핀 id로 그릴 핀을 고른다
    private func pinView3D(id: String, in planData: PlanData) -> AnyView {
        if id.hasPrefix(Pin3DID.photo) {
            let roomID = String(id.dropFirst(Pin3DID.photo.count))
            guard let room = planData.rooms.first(where: { $0.id == roomID }),
                  let pin = photoPins(in: planData)[roomID] else { return AnyView(EmptyView()) }
            return AnyView(PhotoPinView(
                roomName: room.name,
                pin: pin,
                isSelected: room.id == selectedRoomID,
                isDimmed: selectedRoomID != nil && room.id != selectedRoomID
            ) {
                selectRoom(room)
            })
        }
        let memoID = String(id.dropFirst(Pin3DID.memo.count))
        guard let index = memos.firstIndex(where: { $0.id.uuidString == memoID }) else { return AnyView(EmptyView()) }
        return AnyView(MemoPin3DView(number: index + 1))
    }

    /// 3D 핀 id 앞머리. 사진 핀은 장소 id, 메모 핀은 메모 id가 뒤에 붙는다
    private enum Pin3DID {
        static let photo = "photo:"
        static let memo = "memo:"
    }
}

// 사진 핀·놓기
extension FloorPlanTabView {
    /// 화면에 띄울 핀. 패널을 펼친 동안은 기존 핀을 숨기고, 끌고 있는 사진이 올라간 장소에만 미리보기 핀을 띄운다
    private func visiblePins(in planData: PlanData) -> [String: PhotoPin] {
        guard isPlacingPhotos else { return photoPins(in: planData) }
        guard let hoveredRoomID,
              let draggingPhotoID,
              let photo = photoStore.photo(id: draggingPhotoID) else { return [:] }
        // 놓으면 이 장소 사진이 한 장 늘어나므로 지금 수에 1을 더해 보여 준다
        let count = photoStore.photos(inRoom: hoveredRoomID).count + 1
        return [hoveredRoomID: PhotoPin(thumbnail: photo.thumbnail, count: count, isPreview: true)]
    }

    /// 장소마다 가장 최근 사진과 사진 수. 필터에서 사진 표시를 끄면 핀이 없고, 북마크를 고르면 북마크한 사진만 센다.
    /// 북마크 사진 중 정확한 촬영 위치가 있는 것은 번호 핀으로 따로 보이므로 장소 핀에서는 뺀다
    private func photoPins(in planData: PlanData) -> [String: PhotoPin] {
        guard photoFilter.isPhotoVisible else { return [:] }
        let markedIDs = showsBookmarkMarkers ? Set(bookmarkMarkers(in: planData).map(\.id)) : []
        var pins: [String: PhotoPin] = [:]
        for room in planData.rooms {
            let photos = filteredPhotos(inRoom: room.id).filter { !markedIDs.contains($0.id) }
            guard let latest = photos.first else { continue }
            pins[room.id] = PhotoPin(thumbnail: latest.thumbnail, count: photos.count)
        }
        return pins
    }

    /// 북마크 번호 핀을 보여 줄지. 사진을 끌어다 놓는 동안은 숨긴다 (3D에는 아직 없음)
    private var showsBookmarkMarkers: Bool {
        photoFilter.isPhotoVisible && photoFilter.scope == .bookmarked && !isPlacingPhotos
    }

    private func bookmarkMarkers(in planData: PlanData) -> [BookmarkPhotoMarker] {
        BookmarkPhotoMarker.markers(for: photoStore.photos, in: planData)
    }

    /// 북마크 사진 패널의 확대 버튼: 그 사진부터 북마크 사진을 번호 순서로 넘겨 본다
    private func openBookmarkViewer(initialID: UUID) {
        guard let planData else { return }
        viewerContext = PhotoViewerContext(photoIDs: bookmarkMarkers(in: planData).map(\.id), initialID: initialID)
    }

    /// 끌고 있던 사진을 놓은 장소로 옮긴다
    private func dropPhoto(on room: Room) -> Bool {
        defer {
            draggingPhotoID = nil
        }
        guard let draggingPhotoID else { return false }
        withAnimation {
            photoStore.assign(id: draggingPhotoID, toRoom: room.id)
        }
        return true
    }
}

// 2D 확대·이동
extension FloorPlanTabView {
    /// 도면을 화면 크기에 맞춰 다시 놓는다
    private func fitPlan(_ planData: PlanData, in size: CGSize) {
        screen = PlanScreen(plan: planData, in: size, fill: Layout.planFill)
    }

    /// 두 손가락 사이를 기준으로 확대·축소한다
    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                guard let screen else { return }
                let factor = value.magnification / lastMagnification
                lastMagnification = value.magnification
                self.screen = screen.zoomed(by: factor, around: value.startLocation)
            }
            .onEnded { _ in
                lastMagnification = 1
            }
    }

    /// 두 손가락으로 끈 만큼 도면을 옮긴다
    private func panPlan(to location: CGPoint, from previous: CGPoint) {
        screen = screen?.moved(by: CGSize(width: location.x - previous.x, height: location.y - previous.y))
    }
}

// 레이아웃 값
extension FloorPlanTabView {
    private enum Layout {
        /// 화면에서 도면이 차지하는 몫
        static let planFill = 0.85
        /// 북마크 핀을 골랐을 때 나머지 도면·장소 핀을 흐리게 하는 정도
        static let focusDimmedOpacity = 0.35
        /// 위 필터 메뉴·아래 2D/3D 막대와 도면이 겹치지 않게 비우는 위·아래 높이 (pt)
        static let overlayInset: CGFloat = 80
        static let openPanelSpacing: CGFloat = 8
        static let openPanelPadding: CGFloat = 16
        static let openPanelHeight: CGFloat = 48
        /// 3D에서 사진 핀을 띄울 높이 (m). 공간 이름 라벨과 같은 높이라 벽 너머에서는 가려진다
        static let photoPinHeight = 1.5
        /// 3D에서 메모 핀을 띄울 높이 (m). 가구 위에 남긴 메모도 보이게 가구 높이보다 조금 위
        static let memoPinHeight = 1.0
    }
}

// 문구
extension FloorPlanTabView {
    private enum Copy {
        static let placeholder = "도면 자리"
        static let openPanel = "위치 미확인 사진"
    }
}

/// 사진을 끄는 동안 손가락이 움직일 때마다 아래 장소를 알리고, 놓으면 그 장소를 넘긴다.
/// dropDestination은 놓을 때만 위치를 알려 주어, 끄는 동안의 위치도 받는 DropDelegate를 쓴다
private struct PhotoDropDelegate: DropDelegate {
    /// 화면 점 아래의 장소. 장소 밖이면 nil
    let roomAt: (CGPoint) -> Room?
    let onHover: (Room?) -> Void
    let onDrop: (Room) -> Bool

    func dropEntered(info: DropInfo) {
        onHover(roomAt(info.location))
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        let room = roomAt(info.location)
        onHover(room)
        // 장소 밖에서는 놓을 수 없다는 표시(금지 표시)를 보여 준다
        return DropProposal(operation: room == nil ? .forbidden : .move)
    }

    func dropExited(info: DropInfo) {
        onHover(nil)
    }

    func performDrop(info: DropInfo) -> Bool {
        let room = roomAt(info.location)
        onHover(nil)
        guard let room else { return false }
        return onDrop(room)
    }
}

/// 도면 위 한 장소의 사진 핀. 그 장소의 대표 사진과 사진 수. 도면 탭과 내보내기가 함께 쓴다
struct PhotoPin {
    let thumbnail: UIImage
    let count: Int
    /// 끄는 동안 놓일 자리를 미리 보여 주는 핀이면 true. 주황으로 그린다
    var isPreview = false
}

/// 팀 공용 Plan2DView 위에 겹쳐 그리는 사진 핀. 같은 screen으로 자리를 맞춰서 확대·이동하면 핀도 따라 움직인다.
/// "안방 · 13" 캡슐이 도면의 이름 라벨 자리에 그대로 놓이고, 대표 사진은 그 위에 붙는다
struct PhotoPinLayer: View {
    let planData: PlanData
    let screen: PlanScreen
    /// 장소(Room.id)별 사진 핀. 핀이 없는 장소는 그리지 않는다 (이름은 Plan2DView가 그린다)
    let pins: [String: PhotoPin]
    /// 고른 장소. 고른 핀은 검은 캡슐, 나머지 핀은 흐리게 보인다
    let selectedRoomID: String?
    let onTapRoom: (Room) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(planData.rooms) { room in
                if let pin = pins[room.id] {
                    pinView(room: room, pin: pin)
                        // 캡슐 가운데가 라벨 자리에 오도록, 위에 붙은 사진 높이의 절반만큼 올린다
                        .position(screen.point(SIMD2(room.labelX, room.labelY)))
                        .offset(y: -(Layout.pinImageSize + Layout.pinSpacing) / 2)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }

    private func pinView(room: Room, pin: PhotoPin) -> some View {
        PhotoPinView(roomName: room.name, pin: pin, isSelected: room.id == selectedRoomID, isDimmed: selectedRoomID != nil && room.id != selectedRoomID) {
            onTapRoom(room)
        }
    }

    /// 캡슐 가운데가 라벨 자리에 오도록 핀을 올릴 높이 (위에 붙은 사진 높이의 절반)
    private enum Layout {
        static let pinImageSize = PhotoPinView.imageSize
        static let pinSpacing = PhotoPinView.spacing
    }
}

/// 대표 사진 아래 "안방 · 13" 캡슐. 누르면 그 장소를 고른다. 2D 핀과 3D 핀이 함께 쓴다
struct PhotoPinView: View {
    let roomName: String
    let pin: PhotoPin
    /// 고른 핀은 검은 캡슐
    let isSelected: Bool
    /// 다른 장소를 골랐으면 흐리게
    let isDimmed: Bool
    let onTap: () -> Void

    static let imageSize: CGFloat = 64
    static let spacing: CGFloat = 6

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: Self.spacing) {
                Image(uiImage: pin.thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: Self.imageSize, height: Self.imageSize)
                    .clipShape(.rect(cornerRadius: Layout.pinCornerRadius))
                    .overlay {
                        RoundedRectangle(cornerRadius: Layout.pinCornerRadius)
                            .strokeBorder(pin.isPreview ? Color.brand500 : Color.white, lineWidth: pin.isPreview ? Layout.previewBorderWidth : Layout.pinBorderWidth)
                    }
                    .shadow(radius: Layout.pinShadowRadius)
                // 도면 이름 라벨(RoomLabelView)과 같은 글자·여백으로 그려서 라벨을 대신한다
                HStack(spacing: Layout.countSpacing) {
                    Text(roomName)
                    Text("·")
                    Text(pin.count, format: .number)
                        .foregroundStyle(.white.secondary)
                }
                .font(AppTypography.subheadline)
                .foregroundStyle(.white)
                .padding(.horizontal, Layout.capsulePadding)
                .padding(.vertical, Layout.capsuleVerticalPadding)
                .background(capsuleColor, in: .capsule)
            }
            .opacity(isDimmed ? Layout.dimmedOpacity : 1)
        }
        .buttonStyle(.plain)
        // 미리보기 핀은 끄는 중에만 잠깐 보이는 것이라 누를 수 없게 한다
        .allowsHitTesting(!pin.isPreview)
        .accessibilityLabel("\(roomName) 사진 \(pin.count)장")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var capsuleColor: Color {
        if pin.isPreview { return .brand500 }
        return isSelected ? .black : .gray700
    }

    private enum Layout {
        static let pinCornerRadius: CGFloat = 12
        static let pinBorderWidth: CGFloat = 2
        static let previewBorderWidth: CGFloat = 3
        static let pinShadowRadius: CGFloat = 4
        static let countSpacing: CGFloat = 4
        static let capsulePadding: CGFloat = 14
        static let capsuleVerticalPadding: CGFloat = 6
        static let dimmedOpacity: CGFloat = 0.4
    }
}

/// 3D 도면 위 메모 핀. 2D 메모 핀(FloorPlanMemoPlacementOverlay)과 같은 말풍선에 메모 번호
private struct MemoPin3DView: View {
    let number: Int

    var body: some View {
        Image("memoBubble")
            .resizable()
            .frame(width: Layout.size, height: Layout.size * Layout.heightRatio)
            .overlay {
                Text("\(number)")
                    .font(AppTypography.subheadlineEmphasized)
                    .foregroundStyle(.white)
                    .offset(y: Layout.numberOffset)
            }
            .allowsHitTesting(false)
    }

    private enum Layout {
        static let size: CGFloat = 38
        /// 말풍선 그림의 세로·가로 비율
        static let heightRatio: CGFloat = 37 / 40
        static let numberOffset: CGFloat = -2
    }
}

/// 사진 핀을 눌렀을 때 오른쪽에 여는 장소 사진 모음.
/// 제목·확대 버튼은 고정이고, 큰 사진과 사진 목록은 함께 세로로 넘긴다. 목록 사진을 누르면 큰 사진이 바뀐다
private struct RoomPhotoPanel: View {
    let roomName: String
    /// 최근에 찍은 것부터
    let photos: [LoadedPhoto]
    /// 확대 버튼을 누르면 지금 큰 사진의 id를 알린다
    let onExpand: (UUID) -> Void

    /// 크게 보여 줄 사진. 고른 적이 없거나 고른 사진이 사라지면 첫 사진
    @State private var selectedID: UUID?

    private var selectedPhoto: LoadedPhoto? {
        photos.first { $0.id == selectedID } ?? photos.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(Layout.padding)
            ScrollView {
                VStack(spacing: Layout.sectionSpacing) {
                    if let selectedPhoto {
                        Color.clear
                            .aspectRatio(Layout.previewAspectRatio, contentMode: .fit)
                            .overlay {
                                Image(uiImage: selectedPhoto.image)
                                    .resizable()
                                    .scaledToFill()
                            }
                            .clipShape(.rect(cornerRadius: Layout.cornerRadius))
                    }
                    LazyVGrid(columns: Layout.columns, spacing: Layout.gridSpacing) {
                        ForEach(photos) { photo in
                            tile(photo)
                        }
                    }
                }
                .padding(.horizontal, Layout.padding)
                .padding(.bottom, Layout.padding)
            }
        }
    }

    /// "안방 [사진 13장]"과 오른쪽 확대 버튼
    private var header: some View {
        HStack(spacing: Layout.headerSpacing) {
            Text(roomName)
                .font(AppTypography.title2Emphasized)
            Text(Copy.photoCount(photos.count))
                .font(AppTypography.subheadline)
                .padding(.horizontal, Layout.countPadding)
                .padding(.vertical, Layout.countVerticalPadding)
                .background(.gray100, in: .capsule)
            Spacer()
            Button(Copy.expand, systemImage: "arrow.up.left.and.arrow.down.right") {
                guard let selectedPhoto else { return }
                onExpand(selectedPhoto.id)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
        }
    }

    /// 누르면 큰 사진으로 보여 준다. 지금 큰 사진은 주황 테두리
    private func tile(_ photo: LoadedPhoto) -> some View {
        let isSelected = photo.id == selectedPhoto?.id
        return Button {
            selectedID = photo.id
        } label: {
            Color.clear
                .aspectRatio(Layout.tileAspectRatio, contentMode: .fit)
                .overlay {
                    Image(uiImage: photo.thumbnail)
                        .resizable()
                        .scaledToFill()
                }
                .clipShape(.rect(cornerRadius: Layout.cornerRadius))
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: Layout.cornerRadius)
                            .strokeBorder(Color.brand500, lineWidth: Layout.selectedBorderWidth)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private enum Layout {
        static let columns = Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: 3)
        static let padding: CGFloat = 28
        static let headerSpacing: CGFloat = 10
        static let countPadding: CGFloat = 10
        static let countVerticalPadding: CGFloat = 4
        static let sectionSpacing: CGFloat = 24
        static let gridSpacing: CGFloat = 16
        static let cornerRadius: CGFloat = 8
        static let selectedBorderWidth: CGFloat = 3
        static let previewAspectRatio: CGFloat = 1.55
        static let tileAspectRatio: CGFloat = 1.45
    }

    private enum Copy {
        static let expand = "전체 화면으로 보기"
        static func photoCount(_ count: Int) -> String {
            "사진 \(count)장"
        }
    }
}

#Preview {
    @Previewable @State var photoFilter = PhotoFilter()
    @Previewable @State var dimension: FloorPlanTabView.Dimension = .twoD
    @Previewable @State var isPlacingPhotos = false

    FloorPlanTabView(
        photoFilter: $photoFilter,
        dimension: $dimension,
        planData: DummyFloorPlan.planData,
        photoStore: PhotoStore(),
        isPlacingPhotos: $isPlacingPhotos
    )
}

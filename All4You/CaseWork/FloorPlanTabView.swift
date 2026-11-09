// 사건 작업 메인의 도면 탭. 도면(보기 전용)과 사진 핀, 필터 메뉴, 2D/3D 전환, 위치 미확인 사진 패널로 구성된다

import SwiftUI
import UniformTypeIdentifiers

/// 도면을 보고 사진 표시 방식과 2D/3D를 고르는 탭.
/// 위치 미확인 사진 패널을 펼치면 오른쪽 절반에 사진 목록이 나오고, 사진을 2D 도면의 장소로 끌어다 놓는다
struct FloorPlanTabView: View {
    @Binding var photoFilter: PhotoFilter
    @Binding var dimension: Dimension
    /// 보여 줄 도면. 없으면 회색 자리를 보여 준다
    var planData: PlanData? = nil
    let photoStore: PhotoStore
    /// 위치 미확인 사진 패널을 펼쳤는지
    @Binding var isPlacingPhotos: Bool
    /// 도면의 사진 핀을 누르면 그 장소의 앨범을 연다
    let onOpenRoomAlbum: (Room) -> Void

    /// 2D 도면이 화면에 놓인 배율과 자리. 화면 크기를 알게 되면 만든다
    @State private var screen: PlanScreen?
    /// 오므리는 동안 직전까지 적용한 배율. 바뀐 만큼만 screen에 곱한다
    @State private var lastMagnification = 1.0
    /// 패널에서 끌고 있는 사진 (EvidencePhoto.id)
    @State private var draggingPhotoID: UUID?
    /// 끌고 있는 사진이 지금 손가락 아래에 있는 장소 (Room.id). 이 장소에 미리보기 핀을 띄운다
    @State private var hoveredRoomID: String?

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
                    if !isPlacingPhotos && unassignedCount > 0 {
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
            }
        }
    }
}

// 서브 뷰
extension FloorPlanTabView {
    /// 2D는 화면에 맞춰 그리고 두 손가락으로 확대·이동하며, 3D는 돌리고 확대해 볼 수만 있다. 둘 다 고치기는 받지 않는다.
    /// 2D에는 장소별 사진 핀을 겹치고, 위치 미확인 사진을 끌어다 놓으면 놓은 자리의 장소로 옮긴다
    // TODO: 3D 도면에도 사진 핀 띄우기 — Figma에 3D 핀 디자인이 나오면
    @ViewBuilder
    private var floorPlanArea: some View {
        if let planData {
            switch dimension {
            case .twoD:
                GeometryReader { proxy in
                    if let screen {
                        Plan2DView(planData: planData, screen: screen)
                        PhotoPinLayer(
                            planData: planData,
                            screen: screen,
                            pins: visiblePins(in: planData),
                            onTapRoom: onOpenRoomAlbum
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
                .gesture(zoomGesture)
                .gesture(TwoFingerPanGesture(onChanged: panPlan))
            case .threeD:
                // 고른 것이 없고 누르기·편집 알림을 버리므로 카메라 조작만 남는다
                FloorPlan3DView(planData: planData, selection: nil, onTap: { _ in }, onEdit: { _ in })
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

    /// 장소마다 가장 최근 사진과 사진 수. 필터에서 사진 표시를 끄면 핀이 없고, 북마크를 고르면 북마크한 사진만 센다
    // TODO: 필터의 "촬영 방향" 표시 — 촬영 위치·방향 데이터가 생기면
    private func photoPins(in planData: PlanData) -> [String: PhotoPin] {
        guard photoFilter.isPhotoVisible else { return [:] }
        var pins: [String: PhotoPin] = [:]
        for room in planData.rooms {
            let photos = photoStore.photos(inRoom: room.id).filter { photo in
                photoFilter.scope == .all || photo.isBookmarked
            }
            guard let latest = photos.last else { continue }
            pins[room.id] = PhotoPin(thumbnail: latest.thumbnail, count: photos.count)
        }
        return pins
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
        /// 위 필터 메뉴·아래 2D/3D 막대와 도면이 겹치지 않게 비우는 위·아래 높이 (pt)
        static let overlayInset: CGFloat = 80
        static let openPanelSpacing: CGFloat = 8
        static let openPanelPadding: CGFloat = 16
        static let openPanelHeight: CGFloat = 48
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

/// 도면 위 한 장소의 사진 핀. 그 장소의 대표 사진과 사진 수
private struct PhotoPin {
    let thumbnail: UIImage
    let count: Int
    /// 끄는 동안 놓일 자리를 미리 보여 주는 핀이면 true. 주황 테두리로 그린다
    var isPreview = false
}

/// 팀 공용 Plan2DView 위에 겹쳐 그리는 사진 핀. 같은 screen으로 자리를 맞춰서 확대·이동하면 핀도 따라 움직인다.
/// 사진이 있는 장소의 이름 자리에 핀을 띄우고, 누르면 그 장소를 알린다
private struct PhotoPinLayer: View {
    let planData: PlanData
    let screen: PlanScreen
    /// 장소(Room.id)별 사진 핀. 핀이 없는 장소는 그리지 않는다 (이름은 Plan2DView가 그린다)
    let pins: [String: PhotoPin]
    let onTapRoom: (Room) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(planData.rooms) { room in
                if let pin = pins[room.id] {
                    pinView(room: room, pin: pin)
                        .position(screen.point(SIMD2(room.labelX, room.labelY)))
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }

    /// 대표 사진 위에 "안방 · 13" 캡슐. 누르면 그 장소의 앨범으로 간다
    private func pinView(room: Room, pin: PhotoPin) -> some View {
        Button {
            onTapRoom(room)
        } label: {
            VStack(spacing: Layout.pinSpacing) {
                Image(uiImage: pin.thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: Layout.pinImageSize, height: Layout.pinImageSize)
                    .clipShape(.rect(cornerRadius: Layout.pinCornerRadius))
                    .overlay {
                        RoundedRectangle(cornerRadius: Layout.pinCornerRadius)
                            .strokeBorder(pin.isPreview ? Color.brand500 : Color.white, lineWidth: pin.isPreview ? Layout.previewBorderWidth : Layout.pinBorderWidth)
                    }
                    .shadow(radius: Layout.pinShadowRadius)
                HStack(spacing: Layout.countSpacing) {
                    Text(room.name)
                    Text("·")
                    Text(pin.count, format: .number)
                        .foregroundStyle(.white.secondary)
                }
                .font(AppTypography.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, Layout.capsulePadding)
                .padding(.vertical, Layout.capsuleVerticalPadding)
                .background(pin.isPreview ? Color.brand500 : Color.gray700, in: .capsule)
            }
        }
        .buttonStyle(.plain)
        // 미리보기 핀은 끄는 중에만 잠깐 보이는 것이라 누를 수 없게 한다
        .allowsHitTesting(!pin.isPreview)
        .accessibilityLabel("\(room.name) 사진 \(pin.count)장")
    }

    private enum Layout {
        static let pinImageSize: CGFloat = 76
        static let pinCornerRadius: CGFloat = 14
        static let pinBorderWidth: CGFloat = 2
        static let previewBorderWidth: CGFloat = 3
        static let pinShadowRadius: CGFloat = 4
        static let pinSpacing: CGFloat = 8
        static let countSpacing: CGFloat = 4
        static let capsulePadding: CGFloat = 14
        static let capsuleVerticalPadding: CGFloat = 6
    }
}

#Preview {
    @Previewable @State var photoFilter = PhotoFilter()
    @Previewable @State var dimension: FloorPlanTabView.Dimension = .twoD
    @Previewable @State var isPlacingPhotos = true

    FloorPlanTabView(
        photoFilter: $photoFilter,
        dimension: $dimension,
        planData: DummyFloorPlan.planData,
        photoStore: PhotoStore(),
        isPlacingPhotos: $isPlacingPhotos,
        onOpenRoomAlbum: { _ in }
    )
}

// 사건 작업 메인의 도면 탭. 2D·3D 도면, 필터 메뉴, 2D/3D 전환과, 위치 미확인 사진 패널로 구성된다

import SwiftUI

/// 도면을 보고 사진 표시 방식과 2D/3D를 고르는 탭.
/// 위치 미확인 사진 패널을 펼치면 오른쪽 절반에 사진 목록이 나오고, 사진을 2D 도면의 장소로 끌어다 놓는다
struct FloorPlanTabView: View {
    @Binding var photoFilter: PhotoFilter
    @Binding var dimension: Dimension
    let planData: PlanData
    let photoStore: PhotoStore
    /// 위치 미확인 사진 패널을 펼쳤는지
    @Binding var isPlacingPhotos: Bool
    /// 도면의 사진 핀을 누르면 그 장소의 앨범을 연다
    let onOpenRoomAlbum: (Room) -> Void

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
                }
                .frame(maxWidth: .infinity)
                .transition(.move(edge: .trailing))
            }
        }
    }
}

// 서브 뷰
extension FloorPlanTabView {
    // TODO: 3D 도면에도 사진 핀 띄우기 — Figma에 3D 핀 디자인이 나오면
    @ViewBuilder
    private var floorPlanArea: some View {
        switch dimension {
        case .twoD:
            CasePlan2DView(
                planData: planData,
                pins: photoPins,
                isPlacingPhotos: isPlacingPhotos,
                onTapRoom: onOpenRoomAlbum,
                onDropPhoto: { id, room in
                    withAnimation {
                        photoStore.assign(id: id, toRoom: room.id)
                    }
                }
            )
        case .threeD:
            // 메인에서는 도면을 보기만 하므로 누르거나 고친 것은 받지 않는다
            FloorPlan3DView(planData: planData, selection: nil, onTap: { _ in }, onEdit: { _ in })
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

// 사진 핀
extension FloorPlanTabView {
    /// 장소마다 가장 최근 사진과 사진 수. 필터에서 사진 표시를 끄면 핀이 없고, 북마크를 고르면 북마크한 사진만 센다
    // TODO: 필터의 "촬영 방향" 표시 — 촬영 위치·방향 데이터가 생기면
    private var photoPins: [String: RoomPhotoPin] {
        guard photoFilter.isPhotoVisible else { return [:] }
        var pins: [String: RoomPhotoPin] = [:]
        for room in planData.rooms {
            let photos = photoStore.photos(inRoom: room.id).filter { photo in
                photoFilter.scope == .all || photo.isBookmarked
            }
            guard let latest = photos.last else { continue }
            pins[room.id] = RoomPhotoPin(thumbnail: latest.thumbnail, count: photos.count)
        }
        return pins
    }
}

// 크기
extension FloorPlanTabView {
    private enum Layout {
        static let openPanelSpacing: CGFloat = 8
        static let openPanelPadding: CGFloat = 16
        static let openPanelHeight: CGFloat = 48
    }
}

// 문구
extension FloorPlanTabView {
    private enum Copy {
        static let openPanel = "위치 미확인 사진"
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

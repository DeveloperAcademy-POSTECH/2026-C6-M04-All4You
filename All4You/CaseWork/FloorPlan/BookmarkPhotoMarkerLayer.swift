//
//  BookmarkPhotoMarkerLayer.swift
//  All4You
//
//  Created by SIA on 11/10/26.
//

// 도면 탭에서 필터를 "북마크"로 고르면, 북마크한 사진을 찍은 정확한 자리에 "#1" 번호 핀을 띄운다.
// 번호는 찍은 시각 순서. "촬영 방향"을 켜면 핀에서 바라본 쪽으로 화각만큼 벌어진 부채꼴을 그린다
// 촬영 위치는 AR로 찍은 사진(카메라 자세가 있는 사진)만 있다. 나머지 북마크 사진은 지금처럼 장소 핀으로 보인다

import SwiftUI

/// 번호 핀 하나
struct BookmarkPhotoMarker: Identifiable {
    /// 사진 id (LoadedPhoto.id)
    let id: UUID
    /// "#1"의 1
    let number: Int
    let placement: PhotoPlacement
}

extension BookmarkPhotoMarker {
    /// 북마크 전체에 촬영 시각 순서로 번호를 매기고 위치가 있는 사진만 마커로 표시한다
    static func markers(for photos: [LoadedPhoto], in plan: PlanData) -> [BookmarkPhotoMarker] {
        numbered(photos
            .filter(\.isBookmarked)
            .sorted { $0.takenAt < $1.takenAt }
            .enumerated()
            .compactMap { index, photo in
                photo.placement(in: plan).map { (photo.id, index + 1, $0) }
            })
    }
    
    /// 저장된 사진 기록으로 같은 번호를 매긴다 (사건 목록 미리보기처럼 PhotoStore 없이 그릴 때)
    static func markers(for records: [EvidencePhoto], in plan: PlanData) -> [BookmarkPhotoMarker] {
        numbered(records
            .filter(\.isBookmarked)
            .sorted { $0.takenAt < $1.takenAt }
            .enumerated()
            .compactMap { index, record in
                record.placement(in: plan).map { (record.id, index + 1, $0) }
            })
    }
    
    private static func numbered(_ items: [(UUID, Int, PhotoPlacement)]) -> [BookmarkPhotoMarker] {
        items.map { BookmarkPhotoMarker(id: $0.0, number: $0.1, placement: $0.2) }
    }
}

/// Plan2DView 위에 같은 screen으로 겹쳐 그려, 확대·이동하면 핀도 따라 움직인다
struct BookmarkPhotoMarkerLayer: View {
    let markers: [BookmarkPhotoMarker]
    let screen: PlanScreen
    /// 필터의 "촬영 방향"
    let showsDirection: Bool
    /// 고른 핀. 고른 핀만 진하게, 나머지는 흐리게 그린다
    var selectedID: UUID? = nil
    /// 위치 편집 중인 사진과 아직 저장하지 않은 좌표·방향
    var editingID: UUID? = nil
    var editingPosition: SIMD2<Double>? = nil
    var editingYaw: Double? = nil
    /// 전체 사진위치 수정 모드에서는 마커 탭으로 바로 수정
    var isGlobalEditMode = false
    var onBeginEditing: (UUID) -> Void = { _ in }
    var onMoveEditing: (SIMD2<Double>) -> Void = { _ in }
    var onRotateEditing: (Double) -> Void = { _ in }
    var onCancelEditing: () -> Void = {}
    var onSaveEditing: () -> Void = {}
    /// 도면 탭은 큰 "#1" 핀, 사건 목록 미리보기는 작은 "#1" 핀 (누를 수 없음)
    var style: Style = .regular
    /// 핀을 누르면 그 사진 id를 알린다
    var onTap: (UUID) -> Void = { _ in }
    
    enum Style {
        case regular, compact
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            if showsDirection {
                directionCones
            }
            ForEach(markers) { marker in
                if marker.id != editingID {
                    markerButton(marker)
                        .opacity(isDimmed(marker) ? Layout.dimmedOpacity : 1)
                        .position(screen.point(marker.placement.position))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            if let editingID,
               let editingPosition,
               let marker = markers.first(where: { $0.id == editingID }),
               style == .regular {
                editingControls(number: marker.number, position: editingPosition)
                    .position(screen.point(editingPosition))
            }
        }
        .coordinateSpace(name: "bookmarkPhotoMap")
    }
    
    /// 저장 전 미리보기에서도 촬영 방향 부채꼴이 움직이도록 표시 좌표만 대체한다
    private var displayMarkers: [BookmarkPhotoMarker] {
        markers.map { marker in
            guard marker.id == editingID, let editingPosition else { return marker }
            let old = marker.placement
            return BookmarkPhotoMarker(
                id: marker.id,
                number: marker.number,
                placement: PhotoPlacement(
                    position: editingPosition,
                    yaw: editingYaw,
                    pitch: old.pitch,
                    height: old.height,
                    fieldOfView: old.fieldOfView
                )
            )
        }
    }
    
    /// 기존 가구 편집과 같이 주황 테두리 + 취소·회전·저장 손잡이
    private func editingControls(number: Int, position: SIMD2<Double>) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.brand500, lineWidth: 2)
                .frame(width: 80, height: 80)
                .allowsHitTesting(false)
            
            Text("#\(number)")
                .font(AppTypography.headlineEmphasized)
                .foregroundStyle(.white)
                .frame(width: Layout.markerSize, height: Layout.markerSize)
                .background(.brand500, in: .circle)
                .contentShape(.circle)
                .highPriorityGesture(
                    DragGesture(minimumDistance: 2, coordinateSpace: .named("bookmarkPhotoMap"))
                        .onChanged { value in
                            onMoveEditing(screen.plan(value.location))
                        }
                )
                .accessibilityLabel("사진 위치 이동")
            
            editHandle("xmark", title: "위치 수정 취소", action: onCancelEditing)
                .offset(x: -43, y: -43)
            editHandle("checkmark", title: "위치 및 방향 저장", action: onSaveEditing)
                .offset(x: 43, y: 43)
            
            Image(systemName: "arrow.clockwise")
                .font(AppTypography.title3)
                .foregroundStyle(.brand500)
                .frame(width: 44, height: 44)
                .glassEffect(.regular, in: .circle)
                .contentShape(.circle)
                .offset(x: 43, y: -43)
                .highPriorityGesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named("bookmarkPhotoMap"))
                        .onChanged { value in
                            let center = screen.point(position)
                            let dx = Double(value.location.x - center.x)
                            let dy = Double(value.location.y - center.y)
                            onRotateEditing(atan2(dx, -dy) * 180 / .pi)
                        }
                )
                .accessibilityLabel("촬영 방향 회전")
        }
        .frame(width: 132, height: 132)
    }
    
    private func editHandle(_ symbol: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(AppTypography.title3)
                .foregroundStyle(.brand500)
                .frame(width: 44, height: 44)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular, in: .circle)
        .accessibilityLabel(title)
    }
    
    private func markerButton(_ marker: BookmarkPhotoMarker) -> some View {
        Button {
            onTap(marker.id)
        } label: {
            Text("#\(marker.number)")
                .font(style == .compact ? AppTypography.subheadlineEmphasized : AppTypography.headlineEmphasized)
                .monospacedDigit()
                .foregroundStyle(.white)
                .frame(width: markerSize, height: markerSize)
                .background(.brand500, in: .circle)
                .shadow(color: .black.opacity(Layout.shadowOpacity), radius: Layout.shadowRadius, y: 1)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if style == .regular && !isGlobalEditMode {
                Button("위치 및 촬영 방향 수정", systemImage: "arrow.up.left.and.arrow.down.right") {
                    onBeginEditing(marker.id)
                }
            }
        }
        .allowsHitTesting(style == .regular)
        .accessibilityLabel(Copy.markerLabel(marker.number))
        .accessibilityAddTraits(marker.id == selectedID ? .isSelected : [])
    }
    
    private var markerSize: CGFloat {
        style == .compact ? Layout.compactMarkerSize : Layout.markerSize
    }
    
    private func isDimmed(_ marker: BookmarkPhotoMarker) -> Bool {
        selectedID != nil && marker.id != selectedID
    }
    
    /// 핀마다 바라본 쪽으로 화각만큼 벌어진 부채꼴. 도면 좌표로 점을 찍고 screen으로 옮겨 확대해도 길이가 도면과 맞는다
    private var directionCones: some View {
        Canvas { context, _ in
            for marker in displayMarkers {
                guard let yaw = marker.placement.yaw else { continue }
                let center = marker.placement.position
                let half = min(marker.placement.fieldOfView ?? PhotoPlacement.defaultFieldOfView, Layout.maxConeAngle) / 2
                var cone = Path()
                cone.move(to: screen.point(center))
                for step in 0...Layout.arcSteps {
                    let angle = (yaw - half + 2 * half * Double(step) / Double(Layout.arcSteps)) * .pi / 180
                    // yaw: 도면 위쪽 0°, 시계 방향. 도면은 +y가 아래
                    let direction = SIMD2(sin(angle), -cos(angle))
                    cone.addLine(to: screen.point(center + direction * Layout.coneLength))
                }
                cone.closeSubpath()
                // 핀마다 흐림 정도가 달라 복사본에 투명도를 준다
                var coneContext = context
                coneContext.opacity = isDimmed(marker) ? Layout.dimmedOpacity : 1
                coneContext.fill(cone, with: .linearGradient(
                    Gradient(colors: [Color.brand500.opacity(Layout.coneOpacity), Color.brand500.opacity(0)]),
                    startPoint: screen.point(center),
                    endPoint: screen.point(center + SIMD2(sin(yaw * .pi / 180), -cos(yaw * .pi / 180)) * Layout.coneLength)
                ))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
    
    private enum Layout {
        static let markerSize: CGFloat = 40
        /// 사건 목록 미리보기의 작은 핀 지름
        static let compactMarkerSize: CGFloat = 32
        static let shadowOpacity = 0.25
        static let shadowRadius: CGFloat = 3
        /// 부채꼴 길이 (도면 m)
        static let coneLength = 0.5
        /// 광각 사진도 부채꼴이 너무 벌어지지 않게
        static let maxConeAngle = 90.0
        static let coneOpacity = 0.45
        static let arcSteps = 12
        /// 다른 핀을 골랐을 때 흐린 정도
        static let dimmedOpacity = 0.3
    }
    
    private enum Copy {
        static func markerLabel(_ number: Int) -> String {
            "북마크 사진 \(number)번"
        }
    }
}

/// 북마크 번호 핀을 누르면 오른쪽에 여는 사진 패널. "안방 #8" 제목과 큰 사진.
/// 장소 사진 모음(RoomPhotoPanel)과 같은 글자·여백으로 그린다
struct BookmarkPhotoPanel: View {
    /// 사진이 놓인 장소 이름. 장소가 없으면 "위치 미확인"
    let roomName: String?
    let number: Int
    let photo: LoadedPhoto
    /// 확대 버튼: 전체 화면 사진 보기
    let onExpand: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            header
            Color.clear
                .aspectRatio(Layout.previewAspectRatio, contentMode: .fit)
                .overlay {
                    Image(uiImage: photo.image)
                        .resizable()
                        .scaledToFill()
                }
                .clipShape(.rect(cornerRadius: Layout.cornerRadius))
                .onTapGesture(perform: onExpand)
                .accessibilityAddTraits(.isButton)
            Spacer(minLength: 0)
        }
        .padding(Layout.padding)
    }
    
    private var header: some View {
        HStack(spacing: Layout.headerSpacing) {
            Text(roomName ?? Copy.unplaced)
                .font(AppTypography.title2Emphasized)
            Text("#\(number)")
                .font(AppTypography.subheadlineEmphasized)
                .monospacedDigit()
                .padding(.horizontal, Layout.chipPadding)
                .padding(.vertical, Layout.chipVerticalPadding)
                .background(.gray100, in: .capsule)
            Spacer()
            Button(Copy.expand, systemImage: "arrow.up.left.and.arrow.down.right", action: onExpand)
                .labelStyle(.iconOnly)
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
        }
    }
    
    private enum Layout {
        static let padding: CGFloat = 28
        static let sectionSpacing: CGFloat = 24
        static let headerSpacing: CGFloat = 10
        static let chipPadding: CGFloat = 10
        static let chipVerticalPadding: CGFloat = 4
        static let cornerRadius: CGFloat = 8
        static let previewAspectRatio: CGFloat = 1.55
    }
    
    private enum Copy {
        static let unplaced = "위치 미확인"
        static let expand = "전체 화면으로 보기"
    }
}

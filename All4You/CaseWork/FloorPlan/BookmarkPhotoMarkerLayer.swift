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
    /// 북마크 사진 중 촬영 위치가 있는 것을 찍은 시각 순서로 번호를 매긴다
    static func markers(for photos: [LoadedPhoto], in plan: PlanData) -> [BookmarkPhotoMarker] {
        photos
            .filter(\.isBookmarked)
            .sorted { $0.takenAt < $1.takenAt }
            .compactMap { photo in photo.placement(in: plan).map { (photo.id, $0) } }
            .enumerated()
            .map { BookmarkPhotoMarker(id: $0.element.0, number: $0.offset + 1, placement: $0.element.1) }
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
    /// 핀을 누르면 그 사진 id를 알린다
    let onTap: (UUID) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            if showsDirection {
                directionCones
            }
            ForEach(markers) { marker in
                markerButton(marker)
                    .opacity(isDimmed(marker) ? Layout.dimmedOpacity : 1)
                    .position(screen.point(marker.placement.position))
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private func markerButton(_ marker: BookmarkPhotoMarker) -> some View {
        Button {
            onTap(marker.id)
        } label: {
            Text("#\(marker.number)")
                .font(AppTypography.headlineEmphasized)
                .monospacedDigit()
                .foregroundStyle(.white)
                .frame(width: Layout.markerSize, height: Layout.markerSize)
                .background(.brand500, in: .circle)
                .shadow(color: .black.opacity(Layout.shadowOpacity), radius: Layout.shadowRadius, y: 1)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Copy.markerLabel(marker.number))
        .accessibilityAddTraits(marker.id == selectedID ? .isSelected : [])
    }

    private func isDimmed(_ marker: BookmarkPhotoMarker) -> Bool {
        selectedID != nil && marker.id != selectedID
    }

    /// 핀마다 바라본 쪽으로 화각만큼 벌어진 부채꼴. 도면 좌표로 점을 찍고 screen으로 옮겨 확대해도 길이가 도면과 맞는다
    private var directionCones: some View {
        Canvas { context, _ in
            for marker in markers {
                guard let yaw = marker.placement.yaw else { continue }
                let center = marker.placement.position
                let half = min(marker.placement.fieldOfView, Layout.maxConeAngle) / 2
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
        static let shadowOpacity = 0.25
        static let shadowRadius: CGFloat = 3
        /// 부채꼴 길이 (도면 m)
        static let coneLength = 1.5
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

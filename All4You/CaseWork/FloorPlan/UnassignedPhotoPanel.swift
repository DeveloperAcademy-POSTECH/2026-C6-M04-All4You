//
//  UnassignedPhotoPanel.swift
//  All4You
//
//  Created by SIA on 11/9/26.
//

// 도면 탭 오른쪽에 펼치는 위치 미확인 사진 패널. 사진을 길게 눌러 왼쪽 도면의 장소로 끌어다 놓는다

import SwiftUI

/// 위치 미지정 사진 목록. 고른 사진을 크게 보여 주고, 나머지는 아래 3열로 늘어놓는다
struct UnassignedPhotoPanel: View {
    let photos: [EvidencePhoto]
    let onClose: () -> Void
    /// 사진을 끌기 시작하면 그 사진 id를 알린다. 도면이 끄는 동안 미리보기 핀을 보여 주는 데 쓴다
    var onDragStart: (UUID) -> Void = { _ in }

    /// 크게 보여 줄 사진. 고른 적이 없거나 고른 사진이 장소로 옮겨지면 첫 사진을 보여 준다
    @State private var previewID: UUID?

    private var previewPhoto: EvidencePhoto? {
        photos.first { $0.id == previewID } ?? photos.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                header
                if let previewPhoto {
                    preview(previewPhoto)
                }
                LazyVGrid(columns: Layout.columns, spacing: Layout.gridSpacing) {
                    ForEach(photos.filter { $0.id != previewPhoto?.id }) { photo in
                        tile(photo)
                    }
                }
            }
            .padding(Layout.padding)
        }
        .overlay {
            if photos.isEmpty {
                ContentUnavailableView(Copy.emptyTitle, systemImage: "checkmark.circle", description: Text(Copy.emptyMessage))
            }
        }
    }
}

// 서브 뷰
extension UnassignedPhotoPanel {
    /// "위치 미확인 사진 120" 제목과 안내 문구, 오른쪽 닫기
    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Layout.headerSpacing) {
                HStack(spacing: Layout.badgeSpacing) {
                    Text(Copy.title)
                        .font(AppTypography.title2Emphasized)
                    CountBadge(count: photos.count)
                }
                Text(Copy.guide)
                    .font(AppTypography.headline)
            }
            Spacer()
            // TEMP: Figma에 패널을 닫는 버튼이 없어 임의로 둠 — 팀 확인 필요
            Button(Copy.close, systemImage: "xmark", action: onClose)
                .labelStyle(.iconOnly)
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
        }
    }

    /// 크게 보여 주는 고른 사진. 주황빛으로 둘러 지금 옮길 사진임을 보여 준다
    private func preview(_ photo: EvidencePhoto) -> some View {
        Color.clear
            .aspectRatio(Layout.previewAspectRatio, contentMode: .fit)
            .overlay {
                Image(uiImage: photo.thumbnail)
                    .resizable()
                    .scaledToFill()
            }
            .clipShape(.rect(cornerRadius: Layout.cornerRadius))
            .shadow(color: .brand500.opacity(Layout.glowOpacity), radius: Layout.glowRadius)
            .draggablePhoto(photo, onDragStart: onDragStart)
    }

    /// 누르면 크게 보여 주고, 길게 누르면 바로 끌 수 있다
    private func tile(_ photo: EvidencePhoto) -> some View {
        Button {
            previewID = photo.id
        } label: {
            Color.clear
                .aspectRatio(Layout.tileAspectRatio, contentMode: .fit)
                .overlay {
                    Image(uiImage: photo.thumbnail)
                        .resizable()
                        .scaledToFill()
                }
                .clipShape(.rect(cornerRadius: Layout.cornerRadius))
        }
        .buttonStyle(.plain)
        .draggablePhoto(photo, onDragStart: onDragStart)
    }
}

extension View {
    /// 사진 id를 글자로 실어 도면(FloorPlanTabView)에 끌어다 놓을 수 있게 한다. 끄는 동안 작은 사진이 손가락을 따라온다.
    /// draggable은 끌기 시작을 알려 주지 않아서, 시작할 때 부르는 onDrag를 쓴다
    fileprivate func draggablePhoto(_ photo: EvidencePhoto, onDragStart: @escaping (UUID) -> Void) -> some View {
        onDrag {
            onDragStart(photo.id)
            return NSItemProvider(object: photo.id.uuidString as NSString)
        } preview: {
            Image(uiImage: photo.thumbnail)
                .resizable()
                .scaledToFill()
                .frame(width: UnassignedPhotoPanel.Layout.dragPreviewSize, height: UnassignedPhotoPanel.Layout.dragPreviewSize)
                .clipShape(.rect(cornerRadius: UnassignedPhotoPanel.Layout.cornerRadius))
        }
    }
}

/// 빨간 캡슐 안의 흰 숫자. 위치 미지정 사진 수에 쓴다
struct CountBadge: View {
    let count: Int

    var body: some View {
        Text(count, format: .number)
            .font(AppTypography.subheadline)
            .foregroundStyle(.white)
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.vertical, Layout.verticalPadding)
            .background(.red, in: .capsule)
    }

    private enum Layout {
        static let horizontalPadding: CGFloat = 8
        static let verticalPadding: CGFloat = 1
    }
}

// 크기
extension UnassignedPhotoPanel {
    fileprivate enum Layout {
        static let columns = Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: 3)
        static let padding: CGFloat = 32
        static let sectionSpacing: CGFloat = 28
        static let headerSpacing: CGFloat = 8
        static let badgeSpacing: CGFloat = 8
        static let gridSpacing: CGFloat = 18
        static let cornerRadius: CGFloat = 10
        static let previewAspectRatio: CGFloat = 1.6
        static let tileAspectRatio: CGFloat = 1.7
        static let glowOpacity: CGFloat = 0.6
        static let glowRadius: CGFloat = 12
        static let dragPreviewSize: CGFloat = 96
    }
}

// 문구
extension UnassignedPhotoPanel {
    private enum Copy {
        static let title = "위치 미확인 사진"
        static let guide = "사진을 길게 눌러 도면 위치로 드래그하세요"
        static let close = "닫기"
        // TEMP: Figma에 모두 옮긴 뒤의 화면이 없어 임의로 작성한 문구
        static let emptyTitle = "모든 사진의 위치를 정했어요"
        static let emptyMessage = "앨범에서 장소별 사진을 볼 수 있어요."
    }
}

#Preview {
    UnassignedPhotoPanel(photos: [], onClose: {})
}

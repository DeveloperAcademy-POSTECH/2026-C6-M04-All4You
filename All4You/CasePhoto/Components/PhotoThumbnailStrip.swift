//
//  PhotoThumbnailStrip.swift
//  All4You
//
//  Created by SIA on 11/9/26.
//

// 사진 한 장을 크게 보는 화면. 북마크·마크업·삭제를 하고, 옆으로 넘기거나 아래 띠에서 다른 사진을 고른다

import SwiftUI

/// 사진 작은 그림을 가로로 늘어놓은 띠. 고른 사진은 흰 테두리로 보인다
struct PhotoThumbnailStrip: View {
    let photos: [LoadedPhoto]
    /// 고른 사진. 촬영 화면처럼 고른 사진이 없으면 nil
    let selectedID: UUID?
    let onSelect: (UUID) -> Void
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Layout.spacing) {
                    ForEach(photos) { photo in
                        thumbnail(photo)
                            .id(photo.id)
                    }
                }
                .padding(.horizontal, Layout.spacing)
            }
            .frame(height: Layout.height)
            // 고른 사진이 바뀌면(옆으로 넘기거나 새로 찍으면) 그 사진이 보이게 띠를 옮긴다
            .onChange(of: selectedID ?? photos.last?.id, initial: true) { _, id in
                guard let id else { return }
                withAnimation {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
    }
}

// 서브 뷰
extension PhotoThumbnailStrip {
    private func thumbnail(_ photo: LoadedPhoto) -> some View {
        let isSelected = photo.id == selectedID
        return Button {
            onSelect(photo.id)
        } label: {
            Image(uiImage: photo.thumbnail)
                .resizable()
                .scaledToFill()
                .frame(width: Layout.width, height: Layout.height)
                .clipShape(.rect(cornerRadius: Layout.cornerRadius))
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: Layout.cornerRadius)
                            .strokeBorder(.white, lineWidth: Layout.selectedBorderWidth)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(photo.takenAt, format: .dateTime.month().day().hour().minute()))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// 크기
extension PhotoThumbnailStrip {
    private enum Layout {
        static let width: CGFloat = 160
        static let height: CGFloat = 104
        static let spacing: CGFloat = 4
        static let cornerRadius: CGFloat = 6
        static let selectedBorderWidth: CGFloat = 2
    }
}

//
//  FloorPlanMemoTagPicker.swift
//  All4You
//
//  Created by 채유성 on 11/13/26.
//

// 메모 작성과 상세 수정에서 북마크 사진 및 발화지점을 선택하는 공통 목록
import SwiftUI

struct FloorPlanMemoTagPicker: View {
    let photos: [LoadedPhoto]
    let taggedPhotoIDs: Set<UUID>
    let markers: [PlanMarker]
    let taggedMarkerIDs: Set<String>
    let activePhotoID: UUID?
    let onSelectPhoto: (LoadedPhoto, Int) -> Void
    let onSelectMarker: (PlanMarker, Int) -> Void
    
    private let tileSize: CGFloat = 116
    
    private var availableMarkers: [(offset: Int, element: PlanMarker)] {
        Array(markers.enumerated()).filter { !taggedMarkerIDs.contains($0.element.id) }
    }
    
    var body: some View {
        Group {
            if photos.isEmpty && availableMarkers.isEmpty {
                Text(markers.isEmpty
                     ? "발화지점이나 북마크한 사진이 없어요"
                     : "모든 발화지점과 북마크한 사진을 태그했어요")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { scrollProxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .top, spacing: 16) {
                            ForEach(availableMarkers.indices, id: \.self) { index in
                                let entry = availableMarkers[index]
                                Button {
                                    onSelectMarker(entry.element, entry.offset + 1)
                                } label: {
                                    tile(number: entry.offset + 1) {
                                        Image(systemName: "flame.fill")
                                            .font(.system(size: 40))
                                            .foregroundStyle(.orange)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                            .background(Color(uiColor: .systemGray4))
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("발화지점 \(entry.offset + 1) 태그")
                            }
                            
                            ForEach(photos.indices, id: \.self) { index in
                                let photo = photos[index]
                                let isTagged = taggedPhotoIDs.contains(photo.id)
                                
                                Button {
                                    onSelectPhoto(photo, index + 1)
                                } label: {
                                    tile(number: index + 1) {
                                        Image(uiImage: photo.thumbnail)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: tileSize, height: tileSize)
                                            .clipped()
                                            .overlay {
                                                if photo.id == activePhotoID && !isTagged {
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .strokeBorder(Color.brand500, lineWidth: 3)
                                                }
                                            }
                                    }
                                }
                                .buttonStyle(.plain)
                                .disabled(isTagged)
                                .opacity(isTagged ? 0.45 : 1)
                                .id(photo.id)
                                .accessibilityLabel(isTagged
                                                    ? "북마크 사진 \(index + 1), 이미 태그됨"
                                                    : "북마크 사진 \(index + 1) 태그")
                            }
                        }
                        .padding(16)
                    }
                    .onAppear {
                        if let activePhotoID { scrollProxy.scrollTo(activePhotoID, anchor: .center) }
                    }
                    .onChange(of: activePhotoID) { _, photoID in
                        guard let photoID else { return }
                        Task { @MainActor in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                scrollProxy.scrollTo(photoID, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .frame(height: 184)
        .background(Color(uiColor: .systemGray5), in: RoundedRectangle(cornerRadius: 16))
    }
    
    private func tile<Content: View>(number: Int, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 4) {
            content()
                .frame(width: tileSize, height: tileSize)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text("#\(number)")
                .font(AppTypography.headlineEmphasized)
                .foregroundStyle(.primary)
        }
        .frame(width: tileSize)
    }
}

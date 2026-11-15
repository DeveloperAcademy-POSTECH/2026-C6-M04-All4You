//
//  FloorPlanMemoTagPicker.swift
//  All4You
//
//  Created by 채유성 on 11/13/26.
//

// 북마크 사진과 발화지점을 각각의 번호 체계로 보여주는 공통 태그 목록
import SwiftUI

struct FloorPlanMemoTagPicker: View {
    let photos: [LoadedPhoto]
    let taggedPhotoIDs: Set<UUID>
    let markers: [PlanMarker]
    let taggedMarkerIDs: Set<String>
    let activePhotoID: UUID?
    let activeMarkerID: String?
    let onSelectPhoto: (LoadedPhoto, Int) -> Void
    let onSelectMarker: (PlanMarker, Int) -> Void
    var height: CGFloat = 320
    
    private let tileSize: CGFloat = 116
    
    init(
        photos: [LoadedPhoto],
        taggedPhotoIDs: Set<UUID>,
        markers: [PlanMarker],
        taggedMarkerIDs: Set<String>,
        activePhotoID: UUID?,
        activeMarkerID: String? = nil,
        onSelectPhoto: @escaping (LoadedPhoto, Int) -> Void,
        onSelectMarker: @escaping (PlanMarker, Int) -> Void,
        height: CGFloat = 320
    ) {
        self.photos = photos
        self.taggedPhotoIDs = taggedPhotoIDs
        self.markers = markers
        self.taggedMarkerIDs = taggedMarkerIDs
        self.activePhotoID = activePhotoID
        self.activeMarkerID = activeMarkerID
        self.onSelectPhoto = onSelectPhoto
        self.onSelectMarker = onSelectMarker
        self.height = height
    }
    
    private var availablePhotos: [(Int, LoadedPhoto)] {
        photos.enumerated().compactMap { index, photo in
            taggedPhotoIDs.contains(photo.id) ? nil : (index + 1, photo)
        }
    }
    
    private var availableMarkers: [(Int, PlanMarker)] {
        markers.enumerated().compactMap { index, marker in
            taggedMarkerIDs.contains(marker.id) ? nil : (index + 1, marker)
        }
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                if availablePhotos.isEmpty && availableMarkers.isEmpty {
                    Text(photos.isEmpty && markers.isEmpty
                         ? "발화지점이나 북마크한 사진이 없어요"
                         : "모든 발화지점과 북마크한 사진을 태그했어요")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    if !availablePhotos.isEmpty {
                        groupTitle("북마크한 사진")
                        ScrollViewReader { proxy in
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(availablePhotos.indices, id: \.self) { index in
                                        let (number, photo) = availablePhotos[index]
                                        Button {
                                            onSelectPhoto(photo, number)
                                        } label: {
                                            tile(label: "#\(number)") {
                                                Image(uiImage: photo.thumbnail)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: tileSize, height: tileSize)
                                                    .clipped()
                                                    .overlay {
                                                        if photo.id == activePhotoID {
                                                            RoundedRectangle(cornerRadius: 8)
                                                                .strokeBorder(Color.brand500, lineWidth: 3)
                                                        }
                                                    }
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .id(photo.id)
                                        .accessibilityLabel("북마크 사진 \(number) 태그")
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                            .onAppear {
                                if let activePhotoID { proxy.scrollTo(activePhotoID, anchor: .center) }
                            }
                            .onChange(of: activePhotoID) { _, id in
                                guard let id else { return }
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    proxy.scrollTo(id, anchor: .center)
                                }
                            }
                        }
                    }
                    
                    if !availableMarkers.isEmpty {
                        groupTitle("발화지점")
                        ScrollViewReader { proxy in
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(availableMarkers.indices, id: \.self) { index in
                                        let (number, marker) = availableMarkers[index]
                                        Button {
                                            onSelectMarker(marker, number)
                                        } label: {
                                            tile(label: "#\(FloorPlanMemoIgnitionTags.label(at: number - 1))") {
                                                VStack(spacing: 6) {
                                                    Image(systemName: "flame.fill")
                                                        .font(.system(size: 38))
                                                        .foregroundStyle(Color.brand500)
                                                    Text(marker.kindLabel ?? "발화지점")
                                                        .font(.caption)
                                                        .lineLimit(1)
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 3)
                                                        .foregroundStyle(.white)
                                                        .background(Color.brand500, in: Capsule())
                                                }
                                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                                .background(Color(uiColor: .systemGray4))
                                                .overlay {
                                                    if marker.id == activeMarkerID {
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .strokeBorder(Color.brand500, lineWidth: 3)
                                                    }
                                                }
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .id(marker.id)
                                        .accessibilityLabel("발화지점 \(FloorPlanMemoIgnitionTags.label(at: number - 1)) 태그")
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                            .onAppear {
                                if let activeMarkerID { proxy.scrollTo(activeMarkerID, anchor: .center) }
                            }
                            .onChange(of: activeMarkerID) { _, id in
                                guard let id else { return }
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    proxy.scrollTo(id, anchor: .center)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 12)
        }
        .frame(height: height)
        .background(Color(uiColor: .systemGray5), in: RoundedRectangle(cornerRadius: 16))
    }
    
    private func groupTitle(_ title: String) -> some View {
        Text(title)
            .font(AppTypography.headlineEmphasized)
            .padding(.horizontal, 16)
    }
    
    private func tile<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(width: tileSize, height: tileSize)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .topLeading) {
                Text(label)
                    .font(.caption.bold())
                    .padding(7)
            }
            .frame(width: tileSize)
    }
}

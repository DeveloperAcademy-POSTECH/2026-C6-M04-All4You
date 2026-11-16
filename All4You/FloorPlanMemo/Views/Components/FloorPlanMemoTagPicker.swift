//
//  FloorPlanMemoTagPicker.swift
//  All4You
//
//  Created by 채유성 on 11/13/26.
//

// 북마크 사진과 발화지점을 각각의 번호 체계로 보여주는 공통 태그 목록
import SwiftUI

struct FloorPlanMemoTagPicker: View {
    private enum TagCategory: Hashable {
        case photos
        case markers
    }
    
    @State private var selectedCategory: TagCategory = .photos
    
    let photos: [LoadedPhoto]
    let taggedPhotoIDs: Set<UUID>
    let markers: [PlanMarker]
    let taggedMarkerIDs: Set<String>
    let activePhotoID: UUID?
    let activeMarkerID: String?
    let onSelectPhoto: (LoadedPhoto, Int) -> Void
    let onSelectMarker: (PlanMarker, Int) -> Void
    var height: CGFloat = 352
    
    // 키보드 때문에 목록 높이가 줄어들어도 선택 탭과 타일이 함께 보이도록 크기 조절
    private var tileSize: CGFloat { min(116, max(72, height - 68)) }
    // 선택 탭 위, 선택 탭과 타일 사이, 타일 아래의 여백을 같은 크기로 맞춤
    private var verticalGap: CGFloat { max(0, (height - 32 - tileSize) / 3) }
    
    init(
        photos: [LoadedPhoto],
        taggedPhotoIDs: Set<UUID>,
        markers: [PlanMarker],
        taggedMarkerIDs: Set<String>,
        activePhotoID: UUID?,
        activeMarkerID: String? = nil,
        onSelectPhoto: @escaping (LoadedPhoto, Int) -> Void,
        onSelectMarker: @escaping (PlanMarker, Int) -> Void,
        height: CGFloat = 352
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
        VStack(spacing: 0) {
            Picker("태그 종류", selection: $selectedCategory) {
                Text("북마크한 사진").tag(TagCategory.photos)
                Text("발화지점").tag(TagCategory.markers)
            }
            .pickerStyle(.segmented)
            .frame(height: 32)
            .padding(.horizontal, 16)
            .padding(.top, verticalGap)
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    if selectedCategory == .photos && availablePhotos.isEmpty {
                        emptyMessage("북마크한 사진이 없습니다.")
                    } else if selectedCategory == .markers && availableMarkers.isEmpty {
                        emptyMessage("발화지점이 없습니다.")
                    } else {
                        if selectedCategory == .photos {
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
                                .frame(height: tileSize)
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
                        
                        if selectedCategory == .markers {
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
                                .frame(height: tileSize)
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
                // 선택 탭 아래 영역의 가운데에 타일을 배치
                .frame(maxWidth: .infinity)
                .frame(minHeight: max(0, height - 32 - verticalGap), alignment: .center)
            }
        }
        .frame(height: height)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .onAppear {
            if activeMarkerID != nil || availablePhotos.isEmpty {
                selectedCategory = .markers
            }
        }
        .onChange(of: activeMarkerID) { _, id in
            if id != nil { selectedCategory = .markers }
        }
        .onChange(of: activePhotoID) { _, id in
            if id != nil { selectedCategory = .photos }
        }
        .onChange(of: availablePhotos.isEmpty) { _, isEmpty in
            if isEmpty && !availableMarkers.isEmpty { selectedCategory = .markers }
        }
    }
    
    private func emptyMessage(_ message: String) -> some View {
        Text(message)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.top, 50)
            .padding(.bottom, 40)
    }
    
    private func tile<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(width: tileSize, height: tileSize)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .topLeading) {
                Text(label)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.brand500, in: Circle())
                    .padding(6)
            }
            .frame(width: tileSize)
    }
}

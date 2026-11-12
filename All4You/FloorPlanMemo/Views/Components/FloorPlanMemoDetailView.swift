//
//  FloorPlanMemoDetailView.swift
//  All4You
//
//  Created by 채유성 on 11/09/26.
//

import SwiftUI

struct FloorPlanMemoDetailView: View {
    enum Presentation {
        case split
        case expanded
    }
    
    let memo: FloorPlanMemo
    let presentation: Presentation
    let bookmarkedPhotos: [LoadedPhoto]
    var onUpdateMemo: (FloorPlanMemo.ID, String) -> Void = { _, _ in }
    
    @State private var isEditing = false
    @State private var editedContent = ""
    @State private var isEditorFocused = false
    @State private var selectedPhotoIndex = 0
    @State private var photoNavigationRequest = 0
    
    var body: some View {
        GeometryReader { proxy in
            switch presentation {
            case .split:
                splitLayout(width: proxy.size.width)
            case .expanded:
                expandedLayout(size: proxy.size)
            }
        }
        .background(Color(.systemBackground))
        .onDisappear {
            guard isEditing else { return }
            let content = editedContent.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !content.isEmpty, content != memo.content else { return }
            let id = memo.id
            Task { @MainActor in onUpdateMemo(id, content) }
        }
    }
    
    private func splitLayout(width: CGFloat) -> some View {
        let photoWidth = min(476, max(0, width - 62))
        
        return ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    title
                    
                    if !memo.taggedPhotos.isEmpty {
                        photoGallery(width: photoWidth, height: photoWidth * 511 / 476)
                            .id("memo-photo-gallery")
                    }
                    
                    content
                }
                .padding(.horizontal, 31)
                .padding(.top, 18)
                .frame(width: width)
            }
            .onChange(of: photoNavigationRequest) { _, _ in
                withAnimation { scrollProxy.scrollTo("memo-photo-gallery", anchor: .top) }
            }
        }
    }
    
    private func expandedLayout(size: CGSize) -> some View {
        let sidePadding: CGFloat = 32
        let topPadding: CGFloat = 47
        let photoWidth = max(0, size.width - sidePadding * 3) * 0.6
        let photoHeight = max(0, size.height - topPadding - sidePadding)
        
        return ScrollViewReader { scrollProxy in
            ScrollView {
                Group {
                    if memo.taggedPhotos.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            title
                            content
                        }
                    } else {
                        HStack(alignment: .top, spacing: sidePadding) {
                            photoGallery(width: photoWidth, height: photoHeight)
                                .id("memo-photo-gallery")
                                .offset(y: -4)
                            
                            VStack(alignment: .leading, spacing: 16) {
                                title
                                content
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(.horizontal, sidePadding)
                .padding(.top, topPadding)
            }
            .onChange(of: photoNavigationRequest) { _, _ in
                withAnimation { scrollProxy.scrollTo("memo-photo-gallery", anchor: .top) }
            }
        }
    }
    
    private func photoGallery(width: CGFloat, height: CGFloat) -> some View {
        TabView(selection: $selectedPhotoIndex) {
            ForEach(memo.taggedPhotos.indices, id: \.self) { index in
                let photo = memo.taggedPhotos[index]
                Image(uiImage: photo.image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipped()
                    .accessibilityLabel("메모에 태그한 사진")
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(width: width, height: height)
        .clipped()
        .overlay(alignment: .bottom) {
            if memo.taggedPhotos.count > 1 {
                HStack(spacing: 8) {
                    ForEach(memo.taggedPhotos.indices, id: \.self) { index in
                        Circle()
                            .fill(.white.opacity(selectedPhotoIndex == index ? 1 : 0.45))
                            .frame(width: 7, height: 7)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(.black.opacity(0.6), in: Capsule())
                .padding(.bottom, 16)
                .allowsHitTesting(false)
                .accessibilityLabel("사진 \(selectedPhotoIndex + 1) / \(memo.taggedPhotos.count)")
            }
        }
    }
    
    private var title: some View {
        Text(memo.detailTitle)
            .font(AppTypography.title2Emphasized)
            .foregroundStyle(.primary)
    }
    
    @ViewBuilder
    private var content: some View {
        if isEditing {
            FloorPlanMemoInputField(
                text: $editedContent,
                isFocused: $isEditorFocused,
                taggedTokens: [],
                onSubmit: { text in
                    editedContent = text
                    finishEditing()
                },
                textColor: .label
            )
            .frame(height: 180)
            .onChange(of: isEditorFocused) { wasFocused, isFocused in
                if wasFocused && !isFocused { finishEditing() }
            }
        } else {
            FloorPlanMemoInteractiveContent(
                memo: memo,
                bookmarkedPhotos: bookmarkedPhotos,
                onPhotoTap: showPhoto,
                onBodyTap: beginEditing
            )
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .topLeading)
            .accessibilityHint("태그를 누르면 해당 사진을 보고, 다른 부분을 두 번 탭하면 메모를 수정할 수 있습니다")
        }
    }
    
    private func beginEditing() {
        editedContent = memo.content
        isEditing = true
        Task { @MainActor in
            guard isEditing else { return }
            isEditorFocused = true
        }
    }
    
    private func showPhoto(_ photo: LoadedPhoto) {
        guard let index = memo.taggedPhotos.firstIndex(where: { $0.id == photo.id }) else { return }
        selectedPhotoIndex = index
        photoNavigationRequest += 1
    }
    
    private func finishEditing() {
        guard isEditing else { return }
        let content = editedContent.trimmingCharacters(in: .whitespacesAndNewlines)
        isEditing = false
        isEditorFocused = false
        guard !content.isEmpty, content != memo.content else { return }
        onUpdateMemo(memo.id, content)
    }
}

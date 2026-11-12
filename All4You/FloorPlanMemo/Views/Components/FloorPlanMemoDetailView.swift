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
    var onUpdateMemo: (FloorPlanMemo.ID, String) -> Void = { _, _ in }

    @State private var isEditing = false
    @State private var editedContent = ""
    @State private var isEditorFocused = false
    
    var body: some View {
        GeometryReader { proxy in
            switch presentation {
            case .split:
                splitLayout(width: proxy.size.width)
            case .expanded:
                expandedLayout(width: proxy.size.width)
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
        
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                title

                if !memo.taggedPhotos.isEmpty {
                    photoGallery(width: photoWidth, height: photoWidth * 511 / 476)
                }
                
                content
                    .padding(.horizontal, 13)
            }
            .padding(.horizontal, 31)
            .padding(.top, 18)
            .frame(width: width)
        }
    }
    
    private func expandedLayout(width: CGFloat) -> some View {
        let photoWidth = min(540, max(0, (width - 88) * 540 / 1284))
        
        return ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                title

                HStack(alignment: .top, spacing: 24) {
                    if !memo.taggedPhotos.isEmpty {
                        photoGallery(width: photoWidth, height: photoWidth * 580 / 540)
                    }

                    content
                        .padding(.leading, memo.taggedPhotos.isEmpty ? 0 : 32)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 47)
        }
    }
    
    private func photoGallery(width: CGFloat, height: CGFloat) -> some View {
        TabView {
            ForEach(memo.taggedPhotos) { photo in
                Image(uiImage: photo.image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipped()
                    .accessibilityLabel("메모에 태그한 사진")
            }
        }
        .tabViewStyle(.page(indexDisplayMode: memo.taggedPhotos.count > 1 ? .automatic : .never))
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 41, style: .continuous))
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
            Text(memo.content)
                .font(AppTypography.headline)
                .foregroundStyle(.primary)
                .lineSpacing(7)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 60, alignment: .topLeading)
                .contentShape(Rectangle())
                .onTapGesture(perform: beginEditing)
                .accessibilityHint("두 번 탭하면 메모를 수정할 수 있습니다")
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

    private func finishEditing() {
        guard isEditing else { return }
        let content = editedContent.trimmingCharacters(in: .whitespacesAndNewlines)
        isEditing = false
        isEditorFocused = false
        guard !content.isEmpty, content != memo.content else { return }
        onUpdateMemo(memo.id, content)
    }
}

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
    var onUpdateMemo: (FloorPlanMemo.ID, String, [UUID]) -> Void = { _, _, _ in }
    
    @State private var isEditing = false
    @State private var editedContent = ""
    @State private var isEditorFocused = false
    @State private var selectedPhotoIndex = 0
    @State private var photoNavigationRequest = 0
    @State private var taggedPhotoTokens: [UUID: String] = [:]
    @State private var isTagPickerPresented = false
    @State private var confirmedPhotoTagInput: String?
    
    private let editPickerID = "memo-edit-photo-picker"
    private let editPlaceholder = "메모를 입력하세요.\n#을 입력하면 발화지점이나 북마크한 사진을 태그할 수 있어요."
    
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
        .onChange(of: memo.taggedPhotos.map(\.id)) { oldIDs, newIDs in
            if oldIDs.indices.contains(selectedPhotoIndex),
               let newIndex = newIDs.firstIndex(of: oldIDs[selectedPhotoIndex]) {
                selectedPhotoIndex = newIndex
            } else {
                selectedPhotoIndex = min(selectedPhotoIndex, max(0, newIDs.count - 1))
            }
        }
        .onDisappear {
            guard isEditing else { return }
            let content = editedContent.trimmingCharacters(in: .whitespacesAndNewlines)
            let photoIDs = editedPhotoIDs(in: content)
            guard content != memo.content || photoIDs != memo.taggedPhotos.map(\.id) else { return }
            let id = memo.id
            Task { @MainActor in onUpdateMemo(id, content, photoIDs) }
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
            .onChange(of: isTagPickerPresented) { _, isPresented in
                guard isPresented else { return }
                Task { @MainActor in
                    withAnimation { scrollProxy.scrollTo(editPickerID, anchor: .bottom) }
                }
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
            .onChange(of: isTagPickerPresented) { _, isPresented in
                guard isPresented else { return }
                Task { @MainActor in
                    withAnimation { scrollProxy.scrollTo(editPickerID, anchor: .bottom) }
                }
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
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topLeading) {
                    FloorPlanMemoInputField(
                        text: Binding(get: { editedContent }, set: updateEditedContent),
                        isFocused: $isEditorFocused,
                        taggedTokens: Set(taggedPhotoTokens.values),
                        onSubmit: submitEditing,
                        textColor: .label
                    )
                    if editedContent.isEmpty {
                        Text(editPlaceholder)
                            .font(AppTypography.headline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .allowsHitTesting(false)
                    }
                }
                .frame(height: 180)
                
                if isTagPickerPresented {
                    FloorPlanMemoTagPicker(
                        photos: numberedPhotos,
                        taggedPhotoIDs: Set(taggedPhotoTokens.keys),
                        markers: [],
                        taggedMarkerIDs: [],
                        activePhotoID: pendingPhoto(in: editedContent)?.photo.id,
                        onSelectPhoto: { photo, number in tagPhoto(photo, number: number) },
                        onSelectMarker: { _, _ in }
                    )
                    .id(editPickerID)
                    .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
                }
            }
            .animation(.easeOut(duration: 0.22), value: isTagPickerPresented)
            .onChange(of: isEditorFocused) { wasFocused, isFocused in
                if wasFocused && !isFocused && !isTagPickerPresented { finishEditing() }
            }
        } else if memo.content.isEmpty {
            Button(action: beginEditing) {
                Text(editPlaceholder)
                    .font(AppTypography.headline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 60, alignment: .topLeading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
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
        var tokens: [UUID: String] = [:]
        for match in FloorPlanMemoPhotoTags.matches(in: memo, bookmarkedPhotos: bookmarkedPhotos) {
            guard let photo = match.photo else { continue }
            tokens[photo.id] = (memo.content as NSString).substring(with: match.range)
        }
        taggedPhotoTokens = tokens
        isTagPickerPresented = false
        confirmedPhotoTagInput = nil
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
    
    private var numberedPhotos: [LoadedPhoto] {
        bookmarkedPhotos.sorted { $0.takenAt < $1.takenAt }
    }
    
    private func editedPhotoIDs(in content: String) -> [UUID] {
        FloorPlanMemoPhotoTagReconciler.photoIDs(in: content, tokenByPhotoID: taggedPhotoTokens)
    }
    
    private func updateEditedContent(_ newValue: String) {
        if confirmedPhotoTagInput != newValue { confirmedPhotoTagInput = nil }
        editedContent = newValue
        taggedPhotoTokens = taggedPhotoTokens.filter { _, token in
            newValue.range(
                of: NSRegularExpression.escapedPattern(for: token) + "(?![0-9])",
                options: .regularExpression
            ) != nil
        }
        
        // #1 뒤에 공백이나 글자가 이어지면 해당 사진을 태그로 확정
        let source = newValue as NSString
        let range = NSRange(location: 0, length: source.length)
        let matches = (try? NSRegularExpression(pattern: "#([1-9][0-9]*)(?=[^0-9])"))?
            .matches(in: newValue, range: range) ?? []
        for match in matches {
            let token = source.substring(with: match.range)
            guard let number = Int(token.dropFirst()), numberedPhotos.indices.contains(number - 1) else { continue }
            let photo = numberedPhotos[number - 1]
            guard taggedPhotoTokens[photo.id] == nil else { continue }
            taggedPhotoTokens[photo.id] = token
        }
        isTagPickerPresented = pendingTagNumber(in: newValue) != nil
    }
    
    private func pendingTagNumber(in content: String) -> Int? {
        guard let hashIndex = content.lastIndex(of: "#") else { return nil }
        let suffix = content[content.index(after: hashIndex)...]
        guard suffix.allSatisfy(\.isNumber) else { return nil }
        return suffix.isEmpty ? 0 : Int(suffix)
    }
    
    private func pendingPhoto(in content: String) -> (number: Int, photo: LoadedPhoto)? {
        guard let number = pendingTagNumber(in: content), number > 0,
              numberedPhotos.indices.contains(number - 1) else { return nil }
        return (number, numberedPhotos[number - 1])
    }
    
    private func tagPhoto(_ photo: LoadedPhoto, number: Int) {
        guard taggedPhotoTokens[photo.id] == nil else { return }
        let token = "#\(number)"
        if let hashIndex = editedContent.lastIndex(of: "#"), pendingTagNumber(in: editedContent) != nil {
            editedContent = String(editedContent[..<hashIndex]) + token
        } else {
            if !editedContent.isEmpty && !editedContent.hasSuffix(" ") { editedContent += " " }
            editedContent += token
        }
        taggedPhotoTokens[photo.id] = token
        isTagPickerPresented = false
        confirmedPhotoTagInput = editedContent
        Task { @MainActor in
            guard isEditing else { return }
            isEditorFocused = true
        }
    }
    
    private func submitEditing(_ inputText: String) {
        if editedContent != inputText { updateEditedContent(inputText) }
        if confirmedPhotoTagInput == inputText {
            finishEditing()
        } else if let pending = pendingPhoto(in: inputText), taggedPhotoTokens[pending.photo.id] == nil {
            tagPhoto(pending.photo, number: pending.number)
        } else if pendingTagNumber(in: inputText) != nil {
            confirmedPhotoTagInput = inputText
            isTagPickerPresented = false
        } else {
            finishEditing()
        }
    }
    
    private func finishEditing() {
        guard isEditing else { return }
        let content = editedContent.trimmingCharacters(in: .whitespacesAndNewlines)
        let photoIDs = editedPhotoIDs(in: content)
        isEditing = false
        isEditorFocused = false
        isTagPickerPresented = false
        guard content != memo.content || photoIDs != memo.taggedPhotos.map(\.id) else { return }
        onUpdateMemo(memo.id, content, photoIDs)
    }
}

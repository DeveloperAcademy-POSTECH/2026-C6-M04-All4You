//
//  FloorPlanMemoPlacementOverlay.swift
//  All4You
//
//  Created by 채유성 on 11/09/26.
//

//  도면을 눌러 피그마 코멘트처럼 메모를 남기는 오버레이
import SwiftUI

struct FloorPlanMemoPlacementOverlay: View {
    let planData: PlanData
    let memos: [FloorPlanMemo]
    @Binding var isPresented: Bool
    @Binding var draft: FloorPlanMemoDraft?
    let onSave: (FloorPlanMemoDraft) -> Void
    let onCancel: () -> Void
    var onDeleteMemo: (FloorPlanMemo.ID) -> Void = { _ in }
    var onUpdateMemo: (FloorPlanMemo.ID, String) -> Void = { _, _ in }
    var highlightedMemoID: UUID? = nil
    /// 현재 조사 차수의 북마크 사진
    var bookmarkedPhotos: [LoadedPhoto] = []
    /// 도면이 실제로 놓인 화면 자리. 주면 저장된 메모 핀을 이 자리에 맞춰 그려서, 도면을 확대·이동하거나 옆에 사진 모음이 열려 도면이 좁아져도 핀이 따라간다.
    /// nil이면 이 오버레이 크기에 도면을 맞춘 자리로 그린다 (메모 위치를 고를 때)
    var screen: PlanScreen? = nil
    
    @State private var isTextFieldFocused = false
    @State private var selectedMemoID: FloorPlanMemo.ID?
    @State private var editingMemoID: FloorPlanMemo.ID?
    @State private var editingContent = ""
    @State private var isEditingFocused = false
    @State private var previewPhoto: LoadedPhoto?
    @State private var isTagPickerPresented = false
    @State private var keyboardFrame: CGRect = .null
    @State private var taggedPhotoTokens: [UUID: String] = [:]
    @State private var taggedMarkerTokens: [String: String] = [:]
    @State private var confirmedPhotoTagInput: String?
    
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                if isPresented {
                    placementSurface(in: proxy.size)
                } else if selectedMemoID != nil {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            finishEditingMemo()
                            selectedMemoID = nil
                        }
                }
                
                ForEach(memos) { memo in
                    savedPin(for: memo, in: proxy.size)
                }
                
                if isPresented {
                    if let draft {
                        draftEditor(
                            for: draft,
                            in: proxy.size,
                            keyboardTop: keyboardFrame.isNull ? nil : keyboardFrame.minY - proxy.frame(in: .global).minY
                        )
                    } else {
                        instruction
                            .position(x: proxy.size.width / 2, y: Layout.instructionTop)
                    }
                }
                
                if let selectedMemo = memos.first(where: { $0.id == selectedMemoID }) {
                    savedMemoCard(
                        for: selectedMemo,
                        in: proxy.size,
                        keyboardTop: keyboardFrame.isNull ? nil : keyboardFrame.minY - proxy.frame(in: .global).minY
                    )
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isPresented)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
            keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .null
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardFrame = .null
        }
        .onChange(of: draft) { oldDraft, newDraft in
            guard let newDraft else {
                isTagPickerPresented = false
                taggedPhotoTokens = [:]
                taggedMarkerTokens = [:]
                confirmedPhotoTagInput = nil
                return
            }
            guard oldDraft?.anchor != newDraft.anchor else { return }
            isTagPickerPresented = false
            taggedPhotoTokens = [:]
            taggedMarkerTokens = [:]
            confirmedPhotoTagInput = nil
            Task { @MainActor in
                isTextFieldFocused = true
            }
        }
        .sheet(item: $previewPhoto) { photo in
            FloorPlanMemoPhotoPreview(photo: photo)
        }
    }
}

private extension FloorPlanMemoPlacementOverlay {
    func placementSurface(in size: CGSize) -> some View {
        Color.black.opacity(Layout.scrimOpacity)
            .contentShape(Rectangle())
            .onTapGesture { location in
                placeDraft(at: location, in: size)
            }
    }
    
    func placeDraft(at location: CGPoint, in size: CGSize) {
        finishEditingMemo()
        selectedMemoID = nil
        // 입력된 초안이 있으면 도면의 다른 위치를 눌러도 작성 중인 메모를 유지
        guard draft?.content.isEmpty ?? true else { return }
        let canvasSize = drawingSize(in: size)
        guard canvasSize.width > 0, canvasSize.height > 0 else { return }
        
        let canvasPoint = CGPoint(
            x: location.x,
            y: location.y - Layout.floorPlanVerticalInset
        )
        let screen = PlanScreen(plan: planData, in: canvasSize, fill: Layout.planFill)
        let planPoint = screen.plan(canvasPoint)
        let room = planData.room(containing: planPoint)
        
        draft = FloorPlanMemoDraft(
            anchor: FloorPlanMemoAnchor(x: planPoint.x, y: planPoint.y),
            locationID: room?.id,
            locationName: room?.name ?? Copy.otherLocation
        )
    }
    
    func savedPin(for memo: FloorPlanMemo, in size: CGSize) -> some View {
        Button {
            finishEditingMemo()
            isTextFieldFocused = false
            selectedMemoID = selectedMemoID == memo.id ? nil : memo.id
        } label: {
            FloorPlanMemoPinView(
                number: memoNumber(for: memo),
                isHighlighted: memo.id == highlightedMemoID || memo.id == selectedMemoID
            )
            .frame(width: Layout.pinHitSize, height: Layout.pinHitSize)
            .contentShape(.interaction, Rectangle())
            // 기본 컨텍스트 메뉴가 열릴 때 기존 메모 미리보기 닫기
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                    finishEditingMemo()
                    selectedMemoID = nil
                }
            )
            .memoDeleteMenu {
                deleteMemo(memo.id)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(memo.title), \(memo.locationName), 메모 보기")
        .position(screenPoint(for: memo.anchor, in: size))
    }
    
    func savedMemoCard(for memo: FloorPlanMemo, in size: CGSize, keyboardTop: CGFloat?) -> some View {
        let position = cardPosition(
            around: screenPoint(for: memo.anchor, in: size),
            in: size,
            keyboardTop: editingMemoID == memo.id ? keyboardTop : nil,
            cardHeight: editingMemoID == memo.id ? Layout.editingCardHeight : Layout.cardHeight
        )
        
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(memo.title)
                    .font(AppTypography.headlineEmphasized)
                Spacer()
                Button {
                    finishEditingMemo()
                    selectedMemoID = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("메모 닫기")
            }
            
            if editingMemoID == memo.id {
                FloorPlanMemoInputField(
                    text: $editingContent,
                    isFocused: $isEditingFocused,
                    taggedTokens: [],
                    onSubmit: { text in
                        editingContent = text
                        finishEditingMemo()
                    },
                    textColor: .label
                )
                .frame(height: 90)
            } else {
                FloorPlanMemoTaggedContent(memo: memo, bookmarkedPhotos: bookmarkedPhotos) { photo in
                    previewPhoto = photo
                }
                .frame(maxWidth: .infinity, minHeight: 60, alignment: .topLeading)
                .contentShape(Rectangle())
                .onLongPressGesture(minimumDuration: 0.5) { beginEditingMemo(memo) }
                .accessibilityHint("길게 눌러 메모를 수정할 수 있습니다")
                .accessibilityAction(named: "메모 수정") { beginEditingMemo(memo) }
            }
        }
        .padding(20)
        .frame(width: Layout.cardWidth, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
        .position(position)
    }
    
    func deleteMemo(_ id: FloorPlanMemo.ID) {
        if editingMemoID == id {
            editingMemoID = nil
            isEditingFocused = false
        }
        if selectedMemoID == id { selectedMemoID = nil }
        onDeleteMemo(id)
    }
    
    func beginEditingMemo(_ memo: FloorPlanMemo) {
        editingContent = memo.content
        editingMemoID = memo.id
        Task { @MainActor in
            guard editingMemoID == memo.id else { return }
            isEditingFocused = true
        }
    }

    func finishEditingMemo() {
        guard let id = editingMemoID else { return }
        let content = editingContent.trimmingCharacters(in: .whitespacesAndNewlines)
        editingMemoID = nil
        isEditingFocused = false
        guard !content.isEmpty, content != memos.first(where: { $0.id == id })?.content else { return }
        onUpdateMemo(id, content)
    }

    func draftEditor(for draft: FloorPlanMemoDraft, in size: CGSize, keyboardTop: CGFloat?) -> some View {
        let anchorPoint = screenPoint(for: draft.anchor, in: size)
        let editorWidth = min(Layout.editorWidth, size.width - Layout.edgePadding * 2)
        let editorPosition = editorPosition(
            around: anchorPoint,
            in: size,
            editorWidth: editorWidth,
            keyboardTop: keyboardTop
        )
        
        return ZStack(alignment: .topLeading) {
            ZStack(alignment: .topLeading) {
                FloorPlanMemoInputField(
                    text: draftContent,
                    isFocused: $isTextFieldFocused,
                    taggedTokens: Set(taggedPhotoTokens.values),
                    onSubmit: submitDraft
                )
                if draft.content.isEmpty {
                    Text(Copy.placeholder)
                        .font(AppTypography.headline)
                        .foregroundStyle(.white.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                        .allowsHitTesting(false)
                }
            }
            .frame(
                width: editorWidth - Layout.editorHorizontalPadding * 2,
                height: Layout.editorHeight - Layout.editorVerticalPadding * 2,
                alignment: .topLeading
            )
            .padding(.horizontal, Layout.editorHorizontalPadding)
            .padding(.vertical, Layout.editorVerticalPadding)
            .frame(width: editorWidth, height: Layout.editorHeight, alignment: .leading)
            .background(.black, in: RoundedRectangle(cornerRadius: Layout.editorCornerRadius))
            .clipShape(RoundedRectangle(cornerRadius: Layout.editorCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: Layout.editorCornerRadius)
                    .strokeBorder(Color.brand500, lineWidth: Layout.editorBorderWidth)
            }
            .overlay(alignment: .topTrailing) {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.brand500)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
                .padding(.trailing, 4)
                .accessibilityLabel(Copy.cancel)
            }
            .position(editorPosition)
            
            if isTagPickerPresented {
                tagPicker
                    .frame(width: min(Layout.tagPickerWidth, size.width - Layout.edgePadding * 2), height: Layout.tagPickerHeight)
                    .position(
                        x: editorPosition.x,
                        y: editorPosition.y + Layout.editorHeight / 2 + Layout.tagPickerGap + Layout.tagPickerHeight / 2
                    )
            }
        }
    }
    
    var draftContent: Binding<String> {
        Binding(
            get: { draft?.content ?? "" },
            set: { newValue in
                guard var updated = draft else { return }
                if confirmedPhotoTagInput != newValue { confirmedPhotoTagInput = nil }
                updated.content = newValue
                reconcileTags(in: &updated)
                confirmCompletedPhotoTags(in: &updated)
                draft = updated
                // 숫자를 입력하는 동안 후보 표시, 숫자 뒤에 공백·글자가 오면 사진 태그 확정
                isTagPickerPresented = pendingTagNumber(in: newValue) != nil
            }
        )
    }
    
    func pendingTagNumber(in content: String) -> Int? {
        guard let hashIndex = content.lastIndex(of: "#") else { return nil }
        let suffix = content[content.index(after: hashIndex)...]
        guard suffix.allSatisfy(\.isNumber) else { return nil }
        return suffix.isEmpty ? 0 : Int(suffix)
    }
    
    func pendingPhoto(in content: String) -> (number: Int, photo: LoadedPhoto)? {
        guard let number = pendingTagNumber(in: content), number > 0 else { return nil }
        let photos = bookmarkedPhotos.sorted { $0.takenAt < $1.takenAt }
        guard photos.indices.contains(number - 1) else { return nil }
        return (number, photos[number - 1])
    }
    
    func reconcileTags(in draft: inout FloorPlanMemoDraft) {
        taggedPhotoTokens = taggedPhotoTokens.filter { _, token in
            draft.content.range(of: NSRegularExpression.escapedPattern(for: token) + "(?![0-9])", options: .regularExpression) != nil
        }
        taggedMarkerTokens = taggedMarkerTokens.filter { _, token in
            draft.content.range(of: NSRegularExpression.escapedPattern(for: token) + "(?![0-9])", options: .regularExpression) != nil
        }
        draft.taggedPhotoIDs.removeAll { taggedPhotoTokens[$0] == nil }
        draft.taggedMarkerIDs.removeAll { taggedMarkerTokens[$0] == nil }
    }
    
    /// 해시태그 뒤에 숫자 외 문자가 입력되는 경우에만 사진 UUID로 확정
    func confirmCompletedPhotoTags(in draft: inout FloorPlanMemoDraft) {
        let photos = bookmarkedPhotos.sorted { $0.takenAt < $1.takenAt }
        let source = draft.content as NSString
        let pattern = "#([1-9][0-9]*)(?=[^0-9])"
        let matches = (try? NSRegularExpression(pattern: pattern))?
            .matches(in: draft.content, range: NSRange(location: 0, length: source.length)) ?? []
        
        for match in matches {
            let token = source.substring(with: match.range)
            guard let number = Int(token.dropFirst()), photos.indices.contains(number - 1) else { continue }
            let photo = photos[number - 1]
            guard !draft.taggedPhotoIDs.contains(photo.id) else { continue }
            draft.taggedPhotoIDs.append(photo.id)
            taggedPhotoTokens[photo.id] = token
        }
    }
    
    var tagPicker: some View {
        let photos = bookmarkedPhotos.sorted { $0.takenAt < $1.takenAt }
        let markers = planData.markers.filter { $0.kind == .ignitionPoint }
        let activePhotoID = draft.flatMap { pendingPhoto(in: $0.content)?.photo.id }
        // 같은 메모에 이미 태그한 사진은 선택할 수 없도록 표시
        let availablePhotos = Array(photos.enumerated())
        let availableMarkers = Array(markers.enumerated()).filter { !(draft?.taggedMarkerIDs.contains($0.element.id) ?? false) }
        
        return Group {
            if availablePhotos.isEmpty && availableMarkers.isEmpty {
                Text(photos.isEmpty && markers.isEmpty
                     ? "발화지점이나 북마크한 사진이 없어요"
                     : "모든 발화지점과 북마크한 사진을 태그했어요")
                .foregroundStyle(.secondary)
                .padding(20)
            } else {
                ScrollViewReader { scrollProxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .top, spacing: 16) {
                            ForEach(availableMarkers.indices, id: \.self) { index in
                                let marker = availableMarkers[index].element
                                let number = availableMarkers[index].offset + 1
                                Button {
                                    tagMarker(marker, number: number)
                                } label: {
                                    tagTile(number: number) {
                                        Image(systemName: "flame.fill")
                                            .font(.system(size: 40))
                                            .foregroundStyle(.orange)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                            .background(Color(uiColor: .systemGray4))
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("발화지점 \(number) 태그")
                            }
                            
                            ForEach(availablePhotos.indices, id: \.self) { index in
                                let photo = availablePhotos[index].element
                                let number = availablePhotos[index].offset + 1
                                let isTagged = draft?.taggedPhotoIDs.contains(photo.id) ?? false
                                Button {
                                    tagPhoto(photo, number: number)
                                } label: {
                                    tagTile(number: number) {
                                        Image(uiImage: photo.thumbnail)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: Layout.tagTileSize, height: Layout.tagTileSize)
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
                                .accessibilityLabel(isTagged ? "북마크 사진 \(number), 이미 태그됨" : "북마크 사진 \(number) 태그")
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGray5), in: RoundedRectangle(cornerRadius: 16))
    }
    
    func tagTile<Content: View>(number: Int, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 4) {
            content()
                .frame(width: Layout.tagTileSize, height: Layout.tagTileSize)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text("#\(number)")
                .font(AppTypography.headlineEmphasized)
                .foregroundStyle(.primary)
        }
        .frame(width: Layout.tagTileSize)
    }
    
    func tagPhoto(_ photo: LoadedPhoto, number: Int) {
        guard var updated = draft, !updated.taggedPhotoIDs.contains(photo.id) else { return }
        let token = "#\(number)"
        if let hashIndex = updated.content.lastIndex(of: "#"),
           pendingTagNumber(in: updated.content) != nil {
            // 키보드에서 입력한 #번호 또는 #을 탭한 사진 번호로 확정
            updated.content = String(updated.content[..<hashIndex]) + token
        } else {
            appendTag(token, to: &updated)
        }
        reconcileTags(in: &updated)
        updated.taggedPhotoIDs.append(photo.id)
        taggedPhotoTokens[photo.id] = token
        draft = updated
        isTagPickerPresented = false
        confirmedPhotoTagInput = updated.content
        Task { @MainActor in isTextFieldFocused = true }
    }
    
    func tagMarker(_ marker: PlanMarker, number: Int) {
        guard var updated = draft else { return }
        guard !updated.taggedMarkerIDs.contains(marker.id) else { return }
        updated.taggedMarkerIDs.append(marker.id)
        let token = "#발화지점\(number)"
        appendTag(token, to: &updated)
        taggedMarkerTokens[marker.id] = token
        draft = updated
        isTagPickerPresented = false
        Task { @MainActor in isTextFieldFocused = true }
    }
    
    func appendTag(_ tag: String, to draft: inout FloorPlanMemoDraft) {
        if draft.content.hasSuffix("#") { draft.content.removeLast() }
        if !draft.content.isEmpty && !draft.content.hasSuffix(" ") { draft.content += " " }
        draft.content += tag
    }
    
    var trimmedContent: String {
        draft?.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    
    func submitDraft(_ inputText: String) {
        guard var updated = draft else { return }
        // UIKit 입력창의 최신 값을 기준으로 처리해 SwiftUI 바인딩 갱신 순서에 의존하지 않음
        if updated.content != inputText {
            updated.content = inputText
            reconcileTags(in: &updated)
            confirmCompletedPhotoTags(in: &updated)
            draft = updated
        }
        if confirmedPhotoTagInput == inputText {
            saveDraft()
        } else if let pendingPhoto = pendingPhoto(in: inputText) {
            if updated.taggedPhotoIDs.contains(pendingPhoto.photo.id) {
                saveDraft()
            } else {
                tagPhoto(pendingPhoto.photo, number: pendingPhoto.number)
            }
        } else if pendingTagNumber(in: inputText) != nil {
            // #만 있거나 없는 번호라면 첫 Enter에서는 후보 목록만 닫음
            confirmedPhotoTagInput = inputText
            isTagPickerPresented = false
        } else {
            saveDraft()
        }
    }
    
    func saveDraft() {
        guard var completed = draft, !trimmedContent.isEmpty else { return }
        completed.content = trimmedContent
        isTextFieldFocused = false
        onSave(completed)
    }
    
    func drawingSize(in size: CGSize) -> CGSize {
        CGSize(
            width: size.width,
            height: max(1, size.height - Layout.floorPlanVerticalInset * 2)
        )
    }
    
    func screenPoint(for anchor: FloorPlanMemoAnchor, in size: CGSize) -> CGPoint {
        if let screen = self.screen {
            return screen.point(anchor.point)
        }
        let screen = PlanScreen(plan: planData, in: drawingSize(in: size), fill: Layout.planFill)
        let point = screen.point(anchor.point)
        return CGPoint(x: point.x, y: point.y + Layout.floorPlanVerticalInset)
    }
    
    func editorPosition(
        around anchor: CGPoint,
        in size: CGSize,
        editorWidth: CGFloat,
        keyboardTop: CGFloat?
    ) -> CGPoint {
        let preferredX = anchor.x + editorWidth / 2 + Layout.editorOffset
        let preferredY = anchor.y - Layout.editorHeight / 2
        let visibleBottom = min(size.height, keyboardTop ?? size.height) - Layout.edgePadding
        let pickerSpace = isTagPickerPresented ? Layout.tagPickerHeight + Layout.tagPickerGap : 0
        let highestCenter = Layout.editorHeight / 2 + Layout.edgePadding
        let lowestCenter = max(highestCenter, visibleBottom - pickerSpace - Layout.editorHeight / 2)
        return CGPoint(
            x: min(max(preferredX, editorWidth / 2 + Layout.edgePadding), size.width - editorWidth / 2 - Layout.edgePadding),
            y: min(max(preferredY, highestCenter), lowestCenter)
        )
    }
    
    func cardPosition(around anchor: CGPoint, in size: CGSize, keyboardTop: CGFloat?, cardHeight: CGFloat) -> CGPoint {
        let preferredX = anchor.x + Layout.cardWidth / 2 + Layout.editorOffset
        let preferredY = anchor.y - cardHeight / 2
        let visibleBottom = min(size.height, keyboardTop ?? size.height)
        let highestCenter = cardHeight / 2 + Layout.edgePadding
        let lowestCenter = max(highestCenter, visibleBottom - cardHeight / 2 - Layout.edgePadding)
        return CGPoint(
            x: min(max(preferredX, Layout.cardWidth / 2 + Layout.edgePadding), size.width - Layout.cardWidth / 2 - Layout.edgePadding),
            y: min(max(preferredY, highestCenter), lowestCenter)
        )
    }
    
    func memoNumber(for memo: FloorPlanMemo) -> Int {
        (memos.firstIndex(where: { $0.id == memo.id }) ?? 0) + 1
    }
}

private extension FloorPlanMemoPlacementOverlay {
    enum Layout {
        static let planFill = 0.85
        static let floorPlanVerticalInset: CGFloat = 80
        static let scrimOpacity = 0.035
        static let instructionTop: CGFloat = 70
        static let pinSize: CGFloat = 38
        static let pinHitSize: CGFloat = 48
        static let cardWidth: CGFloat = 320
        static let cardHeight: CGFloat = 140
        static let editingCardHeight: CGFloat = 184
        static let editorWidth: CGFloat = 464
        static let editorHeight: CGFloat = 70
        static let editorOffset: CGFloat = 16
        static let editorHorizontalPadding: CGFloat = 16
        static let editorVerticalPadding: CGFloat = 14
        static let editorCornerRadius: CGFloat = 12
        static let editorBorderWidth: CGFloat = 1.5
        static let tagPickerWidth: CGFloat = 464
        static let tagTileSize: CGFloat = 116
        static let tagPickerHeight: CGFloat = 184
        static let tagPickerGap: CGFloat = 8
        static let edgePadding: CGFloat = 16
    }
    
    enum Copy {
        static let placeholder = "메모를 입력하세요.\n#을 입력하면 발화지점이나 북마크한 사진을 태그할 수 있어요."
        static let complete = "메모 작성 완료"
        static let cancel = "메모 작성 취소"
        static let otherLocation = "기타"
    }
    
    var instruction: some View {
        Label("도면에서 메모를 남길 위치를 눌러주세요.", systemImage: "plus.bubble")
            .font(AppTypography.headlineEmphasized)
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(.black.opacity(0.9), in: Capsule())
            .allowsHitTesting(false)
    }
}

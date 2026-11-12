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
    /// 현재 조사 차수의 북마크 사진
    var bookmarkedPhotos: [LoadedPhoto] = []
    /// 도면이 실제로 놓인 화면 자리. 주면 저장된 메모 핀을 이 자리에 맞춰 그려서, 도면을 확대·이동하거나 옆에 사진 모음이 열려 도면이 좁아져도 핀이 따라간다.
    /// nil이면 이 오버레이 크기에 도면을 맞춘 자리로 그린다 (메모 위치를 고를 때)
    var screen: PlanScreen? = nil
    
    @State private var isTextFieldFocused = false
    @State private var selectedMemoID: FloorPlanMemo.ID?
    @State private var isTagPickerPresented = false
    @State private var keyboardFrame: CGRect = .null
    @State private var taggedPhotoTokens: [UUID: String] = [:]
    @State private var taggedMarkerTokens: [String: String] = [:]
    
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                if isPresented {
                    placementSurface(in: proxy.size)
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
                    savedMemoCard(for: selectedMemo, in: proxy.size)
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
                return
            }
            guard oldDraft?.anchor != newDraft.anchor else { return }
            isTagPickerPresented = false
            taggedPhotoTokens = [:]
            taggedMarkerTokens = [:]
            Task { @MainActor in
                isTextFieldFocused = true
            }
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
            .overlay(alignment: .topTrailing) {
                Button(Copy.cancel, systemImage: "xmark") {
                    onCancel()
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .padding(Layout.cancelPadding)
                .accessibilityLabel(Copy.cancel)
            }
    }
    
    func placeDraft(at location: CGPoint, in size: CGSize) {
        let canvasSize = drawingSize(in: size)
        guard canvasSize.width > 0, canvasSize.height > 0 else { return }
        
        let canvasPoint = CGPoint(
            x: location.x,
            y: location.y - Layout.floorPlanVerticalInset
        )
        let screen = PlanScreen(plan: planData, in: canvasSize, fill: Layout.planFill)
        let planPoint = screen.plan(canvasPoint)
        let room = planData.room(containing: planPoint)
        
        selectedMemoID = nil
        draft = FloorPlanMemoDraft(
            anchor: FloorPlanMemoAnchor(x: planPoint.x, y: planPoint.y),
            locationID: room?.id,
            locationName: room?.name ?? Copy.otherLocation
        )
    }
    
    func savedPin(for memo: FloorPlanMemo, in size: CGSize) -> some View {
        Button {
            isTextFieldFocused = false
            selectedMemoID = selectedMemoID == memo.id ? nil : memo.id
        } label: {
            Image("memoBubble")
                .resizable()
                .frame(width: Layout.pinSize, height: Layout.pinSize * 37 / 40)
                .overlay {
                    Text("\(memoNumber(for: memo))")
                        .font(AppTypography.subheadlineEmphasized)
                        .foregroundStyle(.white)
                        .offset(y: -2)
                }
                .frame(width: Layout.pinHitSize, height: Layout.pinHitSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .position(screenPoint(for: memo.anchor, in: size))
        .accessibilityLabel("\(memo.title), \(memo.locationName), 메모 보기")
    }
    
    func savedMemoCard(for memo: FloorPlanMemo, in size: CGSize) -> some View {
        let position = cardPosition(around: screenPoint(for: memo.anchor, in: size), in: size)
        
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(memo.title)
                    .font(AppTypography.headlineEmphasized)
                Spacer()
                Button {
                    selectedMemoID = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("메모 닫기")
            }
            
            Text(memo.content)
                .font(AppTypography.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .frame(width: Layout.cardWidth, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
        .position(position)
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
                    onSubmit: saveDraft
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
                updated.content = newValue
                reconcileTags(in: &updated)
                
                // #3처럼 번호를 직접 입력하면 북마크 목록의 세 번째 사진 UUID를 연결
                if let hashIndex = newValue.lastIndex(of: "#") {
                    let suffix = newValue[newValue.index(after: hashIndex)...]
                    if !suffix.isEmpty, suffix.allSatisfy(\.isNumber),
                       let number = Int(suffix), number > 0 {
                        let photos = bookmarkedPhotos.sorted { $0.takenAt < $1.takenAt }
                        if photos.indices.contains(number - 1) {
                            let photo = photos[number - 1]
                            // 입력 문자열을 바꾸지 않아야 UITextView가 숫자 키 입력과 커서를 유지함
                            // #1 다음에 0을 입력하면 기존 태그가 해제되고 #10으로 다시 연결됨
                            let token = "#\(number)"
                            if !updated.taggedPhotoIDs.contains(photo.id) {
                                updated.taggedPhotoIDs.append(photo.id)
                            }
                            taggedPhotoTokens[photo.id] = token
                            draft = updated
                            isTagPickerPresented = false
                            return
                        }
                    }
                }
                
                draft = updated
                let pendingTag = newValue.split(separator: "#", omittingEmptySubsequences: false).last ?? ""
                isTagPickerPresented = newValue.contains("#") && (pendingTag.isEmpty || pendingTag.allSatisfy(\.isNumber))
            }
        )
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
    
    var tagPicker: some View {
        let photos = bookmarkedPhotos.sorted { $0.takenAt < $1.takenAt }
        let markers = planData.markers.filter { $0.kind == .ignitionPoint }
        let availablePhotos = Array(photos.enumerated()).filter { !(draft?.taggedPhotoIDs.contains($0.element.id) ?? false) }
        let availableMarkers = Array(markers.enumerated()).filter { !(draft?.taggedMarkerIDs.contains($0.element.id) ?? false) }
        
        return Group {
            if availablePhotos.isEmpty && availableMarkers.isEmpty {
                Text(photos.isEmpty && markers.isEmpty
                     ? "발화지점이나 북마크한 사진이 없어요"
                     : "모든 발화지점과 북마크한 사진을 태그했어요")
                .foregroundStyle(.secondary)
                .padding(20)
            } else {
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
                            Button {
                                tagPhoto(photo, number: number)
                            } label: {
                                tagTile(number: number) {
                                    Image(uiImage: photo.thumbnail)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: Layout.tagTileSize, height: Layout.tagTileSize)
                                        .clipped()
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("북마크 사진 \(number) 태그")
                        }
                    }
                    .padding(16)
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
        guard var updated = draft else { return }
        guard !updated.taggedPhotoIDs.contains(photo.id) else { return }
        updated.taggedPhotoIDs.append(photo.id)
        let token = "사진#\(number)"
        appendTag(token, to: &updated)
        taggedPhotoTokens[photo.id] = token
        draft = updated
        isTagPickerPresented = false
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
    
    func cardPosition(around anchor: CGPoint, in size: CGSize) -> CGPoint {
        let preferredX = anchor.x + Layout.cardWidth / 2 + Layout.editorOffset
        let preferredY = anchor.y - Layout.cardHeight / 2
        return CGPoint(
            x: min(max(preferredX, Layout.cardWidth / 2 + Layout.edgePadding), size.width - Layout.cardWidth / 2 - Layout.edgePadding),
            y: min(max(preferredY, Layout.cardHeight / 2 + Layout.edgePadding), size.height - Layout.cardHeight / 2 - Layout.edgePadding)
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
        static let cancelPadding: CGFloat = 16
        static let pinSize: CGFloat = 38
        static let pinHitSize: CGFloat = 48
        static let cardWidth: CGFloat = 320
        static let cardHeight: CGFloat = 140
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

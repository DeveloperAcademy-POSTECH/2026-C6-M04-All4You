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
    
    @FocusState private var isTextFieldFocused: Bool
    @State private var selectedMemoID: FloorPlanMemo.ID?
    
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
                        draftEditor(for: draft, in: proxy.size)
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
        .onChange(of: draft) { _, newDraft in
            guard newDraft != nil else { return }
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
    
    func draftEditor(for draft: FloorPlanMemoDraft, in size: CGSize) -> some View {
        let anchorPoint = screenPoint(for: draft.anchor, in: size)
        let editorPosition = editorPosition(around: anchorPoint, in: size)
        
        return ZStack(alignment: .topLeading) {
            Image("memoBubble")
                .resizable()
                .frame(width: Layout.draftPinSize, height: Layout.draftPinSize * 37 / 40)
                .position(anchorPoint)
            
            HStack(alignment: .bottom, spacing: Layout.editorSpacing) {
                TextField(
                    text: draftContent,
                    prompt: Text(Copy.placeholder).foregroundStyle(.white.opacity(0.7)),
                    axis: .vertical
                ) {
                    Text(Copy.placeholder)
                }
                .lineLimit(1...Layout.maximumLines)
                .textFieldStyle(.plain)
                .font(AppTypography.headline)
                .foregroundStyle(.white)
                .submitLabel(.done)
                .focused($isTextFieldFocused)
                .onSubmit(saveDraft)
                
                Button(action: saveDraft) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: Layout.sendIconSize, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: Layout.sendButtonSize, height: Layout.sendButtonSize)
                        .background(Color.brand500, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(trimmedContent.isEmpty)
                .opacity(trimmedContent.isEmpty ? Layout.disabledOpacity : 1)
                .accessibilityLabel(Copy.complete)
            }
            .padding(.horizontal, Layout.editorHorizontalPadding)
            .padding(.vertical, Layout.editorVerticalPadding)
            .frame(width: Layout.editorWidth, alignment: .leading)
            .background(.black, in: RoundedRectangle(cornerRadius: Layout.editorCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: Layout.editorCornerRadius)
                    .strokeBorder(Color.brand500, lineWidth: Layout.editorBorderWidth)
            }
            .position(editorPosition)
        }
    }
    
    var draftContent: Binding<String> {
        Binding(
            get: { draft?.content ?? "" },
            set: { newValue in
                guard var updated = draft else { return }
                updated.content = newValue
                draft = updated
            }
        )
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
        let screen = PlanScreen(plan: planData, in: drawingSize(in: size), fill: Layout.planFill)
        let point = screen.point(anchor.point)
        return CGPoint(x: point.x, y: point.y + Layout.floorPlanVerticalInset)
    }
    
    func editorPosition(around anchor: CGPoint, in size: CGSize) -> CGPoint {
        let preferredX = anchor.x + Layout.editorWidth / 2 + Layout.editorOffset
        let preferredY = anchor.y - Layout.editorHeight / 2
        return CGPoint(
            x: min(max(preferredX, Layout.editorWidth / 2 + Layout.edgePadding), size.width - Layout.editorWidth / 2 - Layout.edgePadding),
            y: min(max(preferredY, Layout.editorHeight / 2 + Layout.edgePadding), size.height - Layout.editorHeight / 2 - Layout.edgePadding)
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
        static let draftPinSize: CGFloat = 28
        static let cardWidth: CGFloat = 320
        static let cardHeight: CGFloat = 140
        static let editorWidth: CGFloat = 360
        static let editorHeight: CGFloat = 88
        static let editorOffset: CGFloat = 16
        static let editorSpacing: CGFloat = 12
        static let editorHorizontalPadding: CGFloat = 16
        static let editorVerticalPadding: CGFloat = 14
        static let editorCornerRadius: CGFloat = 12
        static let editorBorderWidth: CGFloat = 1.5
        static let sendButtonSize: CGFloat = 32
        static let sendIconSize: CGFloat = 14
        static let maximumLines = 3
        static let disabledOpacity = 0.45
        static let edgePadding: CGFloat = 16
    }
    
    enum Copy {
        static let placeholder = "메모를 입력하세요."
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

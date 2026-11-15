// 직접 그리기 스케치 위에 얹는 스탬프 층. 스탬프를 놓고, 고르고, 끌어 옮기고, 지우고, 기타 라벨 글자를 고친다
// 스케치(PencilKit)는 건드리지 않고, 스탬프는 화면 상태(SketchStamp)로만 둔다

import SwiftUI

/// 위 스탬프 도구에서 고른 도구와 종류. 있으면 스케치를 누른 자리에 스탬프를 놓는다
struct SketchStampPlacement {
    let tool: EditTool
    let option: StampOption?
}

struct SketchStampLayer: View {
    @Binding var stamps: [SketchStamp]
    /// 라벨 글자를 고치는 입력칸의 이 층 안 높이. 고치는 중이 아니면 nil. 입력칸이 키보드에 가릴 때 부모가 스케치를 올리는 데 쓴다
    @Binding var editingLabelY: CGFloat?
    /// 아래 막대에서 고른 도구. 획 선택이면 스탬프를 고르고 옮기고, 지우개면 눌러서 지운다. 펜이면 스탬프는 보기만 한다
    let drawingTool: DrawingTool
    /// 위 스탬프 도구가 켜져 있으면 그 도구와 종류. 켜져 있으면 스탬프를 놓는 일이 먼저다
    let placement: SketchStampPlacement?
    /// 스탬프를 하나 놓았다. 도구를 끄게 한다
    let onPlaced: () -> Void
    /// 스탬프를 바꿨다 (바꾼 뒤, 바꾸기 전). 되돌리기에 기록하게 한다
    let onChange: (_ new: [SketchStamp], _ previous: [SketchStamp]) -> Void

    @State private var selectedId: String?
    /// 끌기를 시작할 때의 스탬프들. 끄는 동안은 화면만 바꾸고 손을 뗄 때 한 번만 알린다
    @State private var dragBase: [SketchStamp]?
    /// 라벨 글자를 고치는 중인 스탬프
    @State private var editingNoteId: String?
    @State private var noteDraft = ""
    @FocusState private var isNoteFocused: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            if placement != nil {
                placeCatcher
            }
            ForEach(stamps) { stamp in
                stampView(stamp)
            }
            selectedHandles
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .coordinateSpace(.named(Layout.space))
        .onChange(of: stamps) {
            // 되돌리기 등으로 사라진 스탬프는 고른 것·고치던 것에서 뺀다
            if let selectedId, !stamps.contains(where: { $0.id == selectedId }) { self.selectedId = nil }
            if let editingNoteId, !stamps.contains(where: { $0.id == editingNoteId }) {
                self.editingNoteId = nil
                editingLabelY = nil
                isNoteFocused = false
            }
        }
        .onChange(of: drawingTool) {
            if drawingTool != .hand { selectedId = nil }
        }
        .onChange(of: placement != nil) {
            if placement != nil { selectedId = nil }
        }
        .onChange(of: isNoteFocused) { _, isFocused in
            if !isFocused, editingNoteId != nil { finishNoteEditing() }
        }
    }
}

// 서브 뷰
extension SketchStampLayer {
    /// 스탬프 도구가 켜져 있을 때 스케치 어디를 눌러도 스탬프를 놓는 투명한 층
    private var placeCatcher: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture().onEnded { value in
                    place(at: value.location)
                }
            )
    }

    /// 아이콘과 종류 라벨(또는 라벨 입력칸)을 한 덩어리로 놓는다. 위치를 한 번만 정해서, 키보드에 맞춰 스케치가 올라가고 내려갈 때 둘이 따로 움직이지 않는다.
    /// 아이콘을 누르면 고르거나 지우고, 끌면 옮긴다
    private func stampView(_ stamp: SketchStamp) -> some View {
        let isSelected = selectedId == stamp.id
        return ZStack {
            icon(of: stamp, isSelected: isSelected)
            if editingNoteId == stamp.id {
                LabelNameField(style: .stamp, placeholder: IgnitionCause.other.title, text: $noteDraft, isFocused: $isNoteFocused, onSubmit: finishNoteEditing, maxLength: PlanData.kindNoteMaxLength)
                    .offset(y: Layout.labelOffset)
            } else if let text = stamp.kindLabel {
                kindLabel(text, of: stamp, isBoxed: isSelected && stamp.isKindOther)
                    .offset(y: Layout.labelOffset)
            }
        }
        .position(stamp.position)
        // 입력칸과 라벨이 바뀌거나 고른 표시가 생길 때 위치가 따로 움직여 보이지 않게, 이 안의 변화는 애니메이션 없이 바로 바꾼다
        .transaction { $0.animation = nil }
    }

    private func icon(of stamp: SketchStamp, isSelected: Bool) -> some View {
        Image(systemName: Plan2DView.iconName(of: stamp.kind))
            .font(.system(size: Layout.iconSize))
            .foregroundStyle(.brand500)
            .frame(width: Layout.iconSize, height: Layout.iconSize)
            .overlay {
                if isSelected {
                    Rectangle()
                        .stroke(.brand500, lineWidth: Layout.selectionLineWidth)
                        .padding(-Plan2DView.selectionPadding)
                }
            }
            .contentShape(Rectangle().inset(by: -Plan2DView.selectionPadding))
            .allowsHitTesting(isInteractive)
            .onTapGesture { tapStamp(stamp.id) }
            .gesture(moveGesture(of: stamp.id))
    }

    /// 스탬프 아래의 종류 라벨. 고른 기타 스탬프는 라벨에만 따로 주황 사각 테두리를 치고, 이 라벨을 누르면 글자를 고친다
    private func kindLabel(_ text: String, of stamp: SketchStamp, isBoxed: Bool) -> some View {
        StampKindLabelView(text: text)
            .overlay {
                if isBoxed {
                    Rectangle()
                        .stroke(.brand500, lineWidth: Layout.selectionLineWidth)
                        .padding(-Plan2DView.kindLabelBoxPadding)
                }
            }
            .allowsHitTesting(isInteractive && isBoxed)
            .onTapGesture { startNoteEditing(stamp.id) }
    }

    /// 고른 스탬프의 ✕ 손잡이. 눌러서 지운다
    @ViewBuilder
    private var selectedHandles: some View {
        if let selectedId, editingNoteId == nil, isInteractive, drawingTool == .hand,
           let stamp = stamps.first(where: { $0.id == selectedId }) {
            let half = Layout.iconSize / 2 + Plan2DView.selectionPadding
            StampHandles2DView(
                center: stamp.position,
                halfSize: CGSize(width: half, height: half),
                yaw: nil,
                scale: nil,
                coordinateSpace: Layout.space,
                onDelete: { delete(stamp.id) },
                onRotate: { _ in },
                onResize: { _ in },
                onDragEnded: {}
            )
        }
    }
}

// 동작
extension SketchStampLayer {
    /// 스탬프를 눌러 다룰 수 있는지. 스탬프 도구가 켜져 있거나 펜일 때는 스케치가 먼저라 누르지 않는다
    private var isInteractive: Bool {
        placement == nil && drawingTool != .pen
    }

    /// 놓는다. 새 스탬프를 고른 상태로 두고, 도구는 한 번 놓으면 꺼진다. 기타면 바로 라벨 글자를 적게 한다.
    /// 발화지점·전기는 종류를 먼저 골라야 놓는다
    private func place(at point: CGPoint) {
        guard let placement else { return }
        if !placement.tool.stampOptions.isEmpty, placement.option == nil { return }
        guard let stamp = SketchStamp(tool: placement.tool, option: placement.option, position: point) else { return }
        let previous = stamps
        stamps.append(stamp)
        onChange(stamps, previous)
        selectedId = stamp.id
        onPlaced()
        if stamp.isKindOther { startNoteEditing(stamp.id) }
    }

    /// 손(획 선택)이면 고르고, 지우개면 지운다
    private func tapStamp(_ id: String) {
        guard isInteractive else { return }
        if editingNoteId != nil {
            finishNoteEditing()
            return
        }
        switch drawingTool {
        case .hand: selectedId = id
        case .eraser: delete(id)
        case .pen: break
        }
    }

    private func delete(_ id: String) {
        let previous = stamps
        stamps.removeAll { $0.id == id }
        onChange(stamps, previous)
        selectedId = nil
    }

    /// 손(획 선택)일 때만 끌어 옮긴다. 끄는 동안은 화면만 바꾸고 손을 떼면 한 번 알린다
    private func moveGesture(of id: String) -> some Gesture {
        DragGesture(minimumDistance: Layout.moveSlop, coordinateSpace: .named(Layout.space))
            .onChanged { value in
                guard isInteractive, drawingTool == .hand else { return }
                let base = dragBase ?? stamps
                dragBase = base
                selectedId = id
                guard let start = base.first(where: { $0.id == id })?.position,
                      let index = stamps.firstIndex(where: { $0.id == id }) else { return }
                stamps[index].position = CGPoint(x: start.x + value.translation.width, y: start.y + value.translation.height)
            }
            .onEnded { _ in
                guard let base = dragBase else { return }
                dragBase = nil
                if base != stamps { onChange(stamps, base) }
            }
    }

    private func startNoteEditing(_ id: String) {
        guard let stamp = stamps.first(where: { $0.id == id }), stamp.isKindOther else { return }
        noteDraft = stamp.kindNote ?? ""
        editingNoteId = id
        editingLabelY = labelCenter(of: stamp).y
        selectedId = nil
        isNoteFocused = true
    }

    /// 적은 글자를 스탬프에 넣고 키보드를 내린다. 비워 두면 "기타"로 남는다. 고치던 스탬프는 다시 고른 상태로 둔다
    private func finishNoteEditing() {
        guard let editingNoteId, let index = stamps.firstIndex(where: { $0.id == editingNoteId }) else { return }
        let previous = stamps
        stamps[index].setKindNote(noteDraft)
        if stamps != previous { onChange(stamps, previous) }
        selectedId = editingNoteId
        self.editingNoteId = nil
        editingLabelY = nil
        isNoteFocused = false
    }

    /// 스탬프 아래 종류 라벨 캡슐의 가운데. 2D와 같이 고른 테두리 바로 아래에 둔다
    private func labelCenter(of stamp: SketchStamp) -> CGPoint {
        CGPoint(x: stamp.position.x, y: stamp.position.y + Layout.labelOffset)
    }
}

// 레이아웃 값
extension SketchStampLayer {
    private enum Layout {
        // TEMP: 스케치 위 스탬프 크기는 실기기에서 보고 정한다
        static let iconSize: CGFloat = 36
        static let selectionLineWidth: CGFloat = 1.5
        /// 아이콘 가운데에서 라벨 가운데까지 아래로 (pt). 2D와 같이 고른 테두리 바로 아래에 둔다
        static let labelOffset = iconSize / 2 + Plan2DView.selectionPadding + Plan2DView.kindLabelGap + StampKindLabelView.height / 2
        /// 이만큼 움직여야 끌기로 본다 (pt). 그보다 짧으면 누르기
        static let moveSlop: CGFloat = 4
        static let space = "sketchStampLayer"
    }
}

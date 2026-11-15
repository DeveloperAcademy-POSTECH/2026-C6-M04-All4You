//
//  FloorPlanDrawingView.swift
//  All4You
//
//  Created by 김가은 on 11/7/26.
//

import SwiftUI
import PencilKit
import Combine

struct FloorPlanDrawingView: View {
    /// 상단 바 부제로 보여 줄 사건 주소
    let address: String
    let onRetake: () -> Void
    let onConfirm: () -> Void

    @Binding var canvasView: PKCanvasView
    /// 스케치 위에 놓은 스탬프. 변환이 끝나면 도면으로 옮기도록 부모가 들고 있는다
    @Binding var sketchStamps: [SketchStamp]

    @State private var selectedTool: DrawingTool = .pen
    @State private var selectedEditTool: EditTool?
    /// 발화지점·전기 도구에서 고른 종류. 도구가 바뀌어 그 도구의 종류가 아니게 되면(끄거나, 한 번 놓아서 꺼지면) 다시 고르게 비운다
    @State private var stampOption: StampOption?
    /// PencilKit 기록이 바뀔 때마다 올려, 되돌리기·다시 하기 버튼이 켜졌는지 다시 읽게 한다
    @State private var undoRefresh = 0
    /// 저장(✓)을 눌러 "이대로 도면을 완성할지" 묻는 알림을 띄우는지
    @State private var isCompleteAlertShown = false
    /// 키보드에 가리지 않게 스케치(그림·스탬프)를 올린 거리 (pt, 올리면 음수)
    @State private var liftOffset: CGFloat = 0
    /// 스케치 영역 윗변의 기기 화면 기준 높이. 올리지 않는 바닥 층에서 재서, 올려도 값이 변하지 않는다
    @State private var originY: CGFloat = 0
    /// 지금 올라와 있는 키보드의 높이 (pt). 내려가 있으면 0
    @State private var keyboardHeight: CGFloat = 0
    /// 라벨 글자를 고치는 입력칸의 스케치 영역 안 높이. 고치는 중이 아니면 nil
    @State private var labelEditY: CGFloat?

    var body: some View {
        GeometryReader { geometry in
            drawingSurface(size: geometry.size)
                .clipped()
        }
        // 키보드가 올라와도 화면 크기가 바뀌지 않게 해서, 스케치가 다시 맞춰지지 않게 한다
        .ignoresSafeArea(.keyboard)
        // 키보드가 올라오고 내려가는 때에 맞춰 올리고 내린다. 2D·3D 수정 화면과 같다
        .onKeyboardChange { height, _ in
            keyboardHeight = height
            updateLift()
        }
        .onChange(of: labelEditY) { updateLift() }
        .navigationTitle("도면 스케치")
        .navigationSubtitle(address)
        .navigationBarTitleDisplayMode(.inline)
        .bothSidesToolbar(
            leadingTitle: "뒤로 가기",
            trailingTitle: "저장",
            customLayout: true,
            barTitle: "도면 스케치",
            barSubtitle: address,
            trailingAccessory: AnyView(undoRedo),
            onBack: onRetake,
            // ✓는 도면을 확정하는 버튼인데 방금 그린 것을 저장하는 버튼으로 오해하기 쉬워서, 한 번 묻는다
            onDone: { isCompleteAlertShown = true }
        )
        .alert(Copy.completeTitle, isPresented: $isCompleteAlertShown) {
            Button(Copy.cancel, role: .cancel) {}
            Button(Copy.complete, action: onConfirm)
        }
        .onReceive(undoChanges) { _ in undoRefresh += 1 }
        .onChange(of: selectedEditTool) {
            // 고른 종류가 지금 도구의 것이 아니면(도구를 바꾸거나 껐거나, 놓아서 도구가 꺼짐) 비워 다시 고르게 한다
            if let stampOption, selectedEditTool?.stampOptions.contains(stampOption) != true { self.stampOption = nil }
        }
    }

    /// 위 스탬프 도구를 켜 두었는지. 켜 두면 스케치를 누르는 것이 스탬프를 놓는 일이다
    private var isStampActive: Bool {
        selectedEditTool != nil
    }

    /// 켜 둔 스탬프 도구와 고른 종류
    private var placement: SketchStampPlacement? {
        selectedEditTool.map { SketchStampPlacement(tool: $0, option: stampOption) }
    }

    /// 아래 막대에서 펜·지우개를 눌렀다. 쓰려는 것이므로 위 스탬프 도구는 끈다. 이미 고른 펜을 다시 눌러도 알려 준다
    private func pickDrawingTool(_ tool: DrawingTool) {
        guard tool != .hand else { return }
        selectedEditTool = nil
        stampOption = nil
    }

    /// 스탬프를 바꾸고 PencilKit 되돌리기 기록에 한 줄로 넣는다. 되돌리는 쪽도 같은 함수로 다시 기록해 다시 하기도 된다
    private func recordStampChange(_ new: [SketchStamp], previous: [SketchStamp]) {
        canvasView.undoManager?.registerUndo(withTarget: canvasView) { _ in
            recordStampChange(previous, previous: new)
        }
        sketchStamps = new
    }

    /// PencilKit 기록(undoManager)에 연결한 되돌리기·다시 하기. undoRefresh는 버튼 상태를 다시 읽게 하려고 읽는다
    private var undoRedo: some View {
        let _ = undoRefresh
        return UndoRedoButtons(
            canUndo: canvasView.undoManager?.canUndo ?? false,
            canRedo: canvasView.undoManager?.canRedo ?? false,
            onUndo: { canvasView.undoManager?.undo() },
            onRedo: { canvasView.undoManager?.redo() }
        )
    }

    /// 기록이 쌓이거나 되돌려질 때마다 오는 알림
    private var undoChanges: some Publisher<Notification, Never> {
        Publishers.MergeMany([
            NotificationCenter.default.publisher(for: .NSUndoManagerDidCloseUndoGroup),
            NotificationCenter.default.publisher(for: .NSUndoManagerDidUndoChange),
            NotificationCenter.default.publisher(for: .NSUndoManagerDidRedoChange)
        ])
    }

    // 스케치(그림·스탬프) 위에 상단 도구와 아래 막대를 배치한다.
    private func drawingSurface(size: CGSize) -> some View {
        ZStack {
            // 높이를 재는 투명한 층은 올리지 않고 스케치만 올린다
            Color.clear
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { originY = $0 }
            sketch
                .offset(y: liftOffset)
        }
        .overlay(alignment: .topLeading) {
            // 2D 수정과 같은 자리·여백. 공간라벨·가구라벨·창문·문은 벽이 있어야 놓을 수 있어 스케치에서는 숨긴다
            EditToolBar(selectedTool: $selectedEditTool, hiddenTools: [.roomName, .furniture, .window, .door], stampOption: $stampOption)
                .padding()
        }
        .overlay(alignment: .topTrailing) {
            // 위쪽이 북쪽이라 방위표가 늘 위를 가리킨다 (2D 수정과 같다)
            CompassView()
                .padding()
        }
        .overlay {
            // 펜·지우개·획 선택 막대 (공용 DrawingToolBar)
            DrawingToolBar(selectedTool: $selectedTool, isPenAndEraserSuspended: isStampActive, onSelect: pickDrawingTool)
        }
    }

    /// 그림과 그 위의 스탬프. 입력칸이 키보드에 가리면 이 덩어리를 함께 올린다
    private var sketch: some View {
        FloorPlanCanvasView(
            canvasView: canvasView,
            // 위 스탬프 도구가 켜져 있으면 스케치 그리기를 끈다. 스탬프를 놓는 손가락이 획으로 그려지지 않게
            tool: isStampActive ? nil : selectedTool.pencilKitTool
        )
        .overlay {
            if selectedTool == .hand {
                FloorPlanStrokeSelection(canvasView: canvasView)
            }
        }
        // 스탬프는 획 선택 층 위에 얹어, 겹치면 스탬프가 먼저 눌린다
        .overlay {
            SketchStampLayer(
                stamps: $sketchStamps,
                editingLabelY: $labelEditY,
                drawingTool: selectedTool,
                placement: placement,
                onPlaced: {
                    // 한 번 놓으면 도구가 꺼진다
                    selectedEditTool = nil
                },
                onChange: recordStampChange
            )
        }
    }

    /// 입력칸이 키보드에 가릴 때만, 가리지 않을 만큼 스케치를 올린다. 올리고 내리는 때는 키보드가 알려 준다
    private func updateLift() {
        let target = KeyboardHeight.lift(labelY: labelEditY, originY: originY, keyboardHeight: keyboardHeight)
        guard target != liftOffset else { return }
        withAnimation(KeyboardHeight.animation) { liftOffset = target }
    }
}

// 공용 막대의 도구를 PencilKit 도구로 바꾼다. 이 화면에서만 쓴다
private extension DrawingTool {
    var pencilKitTool: (any PKTool)? {
        switch self {
        case .pen:
            PKInkingTool(.pen, color: .black, width: 2.0)
        case .eraser:
            PKEraserTool(.vector)
        case .hand:
            nil
        }
    }
}

// PencilKit 캔버스에 입력 방식과 선택한 도구를 적용한다.
private struct FloorPlanCanvasView: UIViewRepresentable {
    let canvasView: PKCanvasView
    let tool: (any PKTool)?

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.backgroundColor = .white
        canvasView.drawingPolicy = .anyInput
        canvasView.isScrollEnabled = false
        // 펜을 멈추면 직선으로 바꿔 주는 인식기. 캔버스가 다시 만들어져도 하나만 붙인다
        if !(canvasView.gestureRecognizers ?? []).contains(where: { $0 is StraightStrokeRecognizer }) {
            canvasView.addGestureRecognizer(StraightStrokeRecognizer(canvas: canvasView))
        }
        applyTool(to: canvasView)
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        applyTool(to: uiView)
    }

    private func applyTool(to canvas: PKCanvasView) {
        if let tool {
            canvas.tool = tool
        }
        let straightener = canvas.gestureRecognizers?.compactMap { $0 as? StraightStrokeRecognizer }.first
        // 직선으로 바꾸는 중에는 PencilKit의 그리기를 꺼 둔 채로 두고, 손을 뗄 때 인식기가 다시 켠다
        if straightener?.isStraightening != true {
            canvas.drawingGestureRecognizer.isEnabled = tool != nil
        }
        // 직선 보정은 펜일 때만 쓴다
        straightener?.isEnabled = tool is PKInkingTool
    }
}

// 문구
extension FloorPlanDrawingView {
    private enum Copy {
        // TEMP: Figma에 알림 버튼 문구가 없어 임의로 작성 — 디자인 확인 필요
        static let completeTitle = "이대로 도면을 완성하시겠습니까?"
        static let complete = "완성"
        static let cancel = "취소"
    }
}

struct FloorPlanDrawingPreview: View {
    @State private var canvasView = PKCanvasView()
    @State private var sketchStamps: [SketchStamp] = []

    var body: some View {
        NavigationStack {
            FloorPlanDrawingView(
                address: "서울시 강남구 청암로 77",
                onRetake: {},
                onConfirm: {},
                canvasView: $canvasView,
                sketchStamps: $sketchStamps
            )
        }
    }
}

#Preview {
    FloorPlanDrawingPreview()
}

// 획을 선택하고 이동·회전·크기 조절·삭제를 처리한다.
private struct FloorPlanStrokeSelection: View {
    let canvasView: PKCanvasView

    @State private var selection: Set<Int> = []
    @State private var originalDrawing: PKDrawing?
    @State private var editedBox: SelectionBox?
    @State private var marquee: CGRect?
    @State private var initialBox: SelectionBox?
    @State private var mode: DragMode?

    // 선택 박스와 획에 같은 변환을 적용한다.
    private struct SelectionBox {
        let bounds: CGRect
        var transform: CGAffineTransform = .identity

        var center: CGPoint { corner(bounds.midX, bounds.midY) }
        var angle: CGFloat { atan2(transform.b, transform.a) }
        var scale: CGFloat { hypot(transform.a, transform.b) }

        func corner(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: x, y: y).applying(transform)
        }

        func contains(_ point: CGPoint) -> Bool {
            bounds.contains(point.applying(transform.inverted()))
        }
    }

    private enum DragMode {
        case move, marquee, rotate, resize
    }

    var body: some View {
        GeometryReader { geometry in
            Color.clear
                .contentShape(Rectangle())
                .gesture(drag())
                .simultaneousGesture(
                    SpatialTapGesture().onEnded { value in
                        editedBox = nil
                        selection = hitStroke(at: value.location).map { [$0] } ?? []
                    }
                )

            if let marquee {
                Rectangle()
                    .fill(.orange.opacity(0.12))
                    .overlay { Rectangle().strokeBorder(.orange, lineWidth: 2) }
                    .frame(width: marquee.width, height: marquee.height)
                    .position(x: marquee.midX, y: marquee.midY)
                    .allowsHitTesting(false)
            }

            if let box = selectionBox {
                let bounds = box.bounds
                Rectangle()
                    .strokeBorder(.orange, lineWidth: 2)
                    .frame(width: bounds.width * box.scale, height: bounds.height * box.scale)
                    .rotationEffect(.radians(box.angle))
                    .position(box.center)
                    .allowsHitTesting(false)

                Button {
                    let previous = canvasView.drawing
                    let remaining = previous.strokes.enumerated().compactMap { index, stroke in
                        selection.contains(index) ? nil : stroke
                    }
                    canvasView.drawing = PKDrawing(strokes: remaining)
                    editedBox = nil
                    registerUndo(previous)
                    selection.removeAll()
                } label: {
                    handle("xmark")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("선택한 획 삭제")
                .position(handlePosition(box.corner(bounds.minX, bounds.minY), in: geometry.size))

                Button {
                    let previous = canvasView.drawing
                    apply(transform(.init(rotationAngle: .pi / 2), around: box.center), to: previous, box: box)
                    registerUndo(previous)
                } label: {
                    handle("arrow.clockwise")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("선택한 획 90도 회전")
                .highPriorityGesture(drag(.rotate))
                .position(handlePosition(box.corner(bounds.maxX, bounds.minY), in: geometry.size))

                handle("arrow.up.left.and.arrow.down.right")
                    .accessibilityLabel("선택한 획 크기 조절")
                    .gesture(drag(.resize))
                    .position(handlePosition(box.corner(bounds.maxX, bounds.maxY), in: geometry.size))
            }
        }
        .coordinateSpace(name: "strokeSelection")
    }

    private var selectionBox: SelectionBox? {
        if let editedBox { return editedBox }
        let drawing = canvasView.drawing
        let bounds = drawing.strokes.enumerated().reduce(CGRect.null) { bounds, entry in
            selection.contains(entry.offset) ? bounds.union(entry.element.renderBounds) : bounds
        }
        guard !bounds.isNull else { return nil }
        return SelectionBox(bounds: bounds
            .offsetBy(dx: -canvasView.contentOffset.x, dy: -canvasView.contentOffset.y)
            .insetBy(dx: -12, dy: -12))
    }

    private func handle(_ icon: String) -> some View {
        Image(systemName: icon)
            .foregroundStyle(.orange)
            .frame(width: 44, height: 44)
            .background(Color(red: 231.0 / 255, green: 231.0 / 255, blue: 233.0 / 255), in: Circle())
            .contentShape(Circle())
    }

    private func handlePosition(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: min(max(point.x, 22), size.width - 22), y: min(max(point.y, 22), size.height - 22))
    }

    // 포인터에 가까운 획 중 가장 위에 그려진 획을 찾는다.
    private func hitStroke(at point: CGPoint) -> Int? {
        let drawingPoint = CGPoint(
            x: point.x + canvasView.contentOffset.x,
            y: point.y + canvasView.contentOffset.y
        )
        return canvasView.drawing.strokes.indices.reversed().first { index in
            let stroke = canvasView.drawing.strokes[index]
            guard stroke.renderBounds.insetBy(dx: -10, dy: -10).contains(drawingPoint) else {
                return false
            }
            return stroke.path.interpolatedPoints(by: .distance(3)).contains { sample in
                let location = sample.location.applying(stroke.transform)
                return hypot(location.x - drawingPoint.x, location.y - drawingPoint.y) <= 10
            }
        }
    }

    // 드래그를 시작한 위치와 핸들에 따라 선택 또는 편집을 시작한다.
    private func drag(_ requestedMode: DragMode? = nil) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named("strokeSelection"))
            .onChanged { value in
                if mode == nil {
                    if let requestedMode {
                        mode = requestedMode
                    } else if let hit = hitStroke(at: value.startLocation) {
                        if !selection.contains(hit) {
                            editedBox = nil
                            selection = [hit]
                        }
                        mode = .move
                    } else if selectionBox?.contains(value.startLocation) == true {
                        mode = .move
                    } else {
                        editedBox = nil
                        mode = .marquee
                    }
                    originalDrawing = canvasView.drawing
                    initialBox = selectionBox
                }

                guard let mode, let originalDrawing else { return }
                switch mode {
                case .marquee:
                    let rect = CGRect(
                        x: min(value.startLocation.x, value.location.x),
                        y: min(value.startLocation.y, value.location.y),
                        width: abs(value.translation.width),
                        height: abs(value.translation.height)
                    )
                    marquee = rect
                    let drawingRect = rect.offsetBy(
                        dx: canvasView.contentOffset.x, dy: canvasView.contentOffset.y
                    )
                    selection = Set(originalDrawing.strokes.indices.filter { index in
                        let stroke = originalDrawing.strokes[index]
                        return stroke.renderBounds.intersects(drawingRect)
                            && stroke.path.interpolatedPoints(by: .distance(3)).contains {
                                drawingRect.contains($0.location.applying(stroke.transform))
                            }
                    })
                case .move:
                    apply(
                        CGAffineTransform(translationX: value.translation.width, y: value.translation.height),
                        to: originalDrawing, box: initialBox
                    )
                case .rotate, .resize:
                    guard let box = initialBox else { return }
                    let pivot = mode == .rotate
                        ? box.center
                        : box.corner(box.bounds.minX, box.bounds.minY)
                    let start = CGPoint(x: value.startLocation.x - pivot.x, y: value.startLocation.y - pivot.y)
                    let end = CGPoint(x: value.location.x - pivot.x, y: value.location.y - pivot.y)
                    let operation: CGAffineTransform
                    if mode == .rotate {
                        operation = CGAffineTransform(rotationAngle: atan2(end.y, end.x) - atan2(start.y, start.x))
                    } else {
                        let scale = max(0.1, hypot(end.x, end.y) / max(1, hypot(start.x, start.y)))
                        operation = CGAffineTransform(scaleX: scale, y: scale)
                    }
                    apply(transform(operation, around: pivot), to: originalDrawing, box: box)
                }
            }
            .onEnded { _ in
                if mode != .marquee, let originalDrawing {
                    registerUndo(originalDrawing)
                }
                mode = nil
                marquee = nil
                originalDrawing = nil
                initialBox = nil
            }
    }

    private func transform(_ operation: CGAffineTransform, around pivot: CGPoint) -> CGAffineTransform {
        let x = pivot.x
        let y = pivot.y
        return CGAffineTransform(translationX: -x, y: -y)
            .concatenating(operation)
            .concatenating(CGAffineTransform(translationX: x, y: y))
    }

    private func apply(_ transform: CGAffineTransform, to drawing: PKDrawing, box: SelectionBox?) {
        let offset = canvasView.contentOffset
        let drawingTransform = CGAffineTransform(translationX: -offset.x, y: -offset.y)
            .concatenating(transform)
            .concatenating(CGAffineTransform(translationX: offset.x, y: offset.y))
        let updatedDrawing = PKDrawing(strokes: drawing.strokes.enumerated().map { index, stroke in
            guard selection.contains(index) else { return stroke }
            var updated = stroke
            updated.transform = updated.transform.concatenating(drawingTransform)
            return updated
        })
        canvasView.drawing = updatedDrawing
        if var box {
            box.transform = box.transform.concatenating(transform)
            editedBox = box
        }
    }

    private func registerUndo(_ drawing: PKDrawing) {
        canvasView.undoManager?.registerUndo(withTarget: canvasView) { canvas in
            canvas.drawing = drawing
            editedBox = nil
            selection.removeAll()
        }
    }
}

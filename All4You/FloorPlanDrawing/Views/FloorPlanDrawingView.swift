//
//  FloorPlanDrawingView.swift
//  All4You
//
//  Created by 김가은 on 11/7/26.
//

import SwiftUI
import PencilKit

struct FloorPlanDrawingView: View {
    let onRetake: () -> Void
    let onConfirm: () -> Void

    @Binding var canvasView: PKCanvasView

    @State private var selectedTool: DrawingTool = .pen
    @State private var selectedEditTool: EditTool?
    @State private var toolbarPosition: ToolbarPosition = .bottom

    @GestureState private var toolbarDrag: CGSize = .zero

    private static let toolSize: CGFloat = 44
    private static let toolbarPadding: CGFloat = 4
    private static let toolbarEdgeInset: CGFloat = 32

    var body: some View {
        GeometryReader { geometry in
            drawingSurface(size: geometry.size)
                .clipped()
        }
        .navigationTitle("도면 스케치")
        .navigationSubtitle("청암로 77")  // TODO: 주소 불러온 걸로 바꾸기
        .navigationBarTitleDisplayMode(.inline)
        .bothSidesToolbar(
            leadingTitle: "뒤로 가기",
            trailingTitle: "저장",
            customLayout: true,
            barTitle: "도면 스케치",
            barSubtitle: "청암로 77",  // TODO: 주소 불러온 걸로 바꾸기
            onBack: onRetake,
            onDone: onConfirm
        )
    }

    // 캔버스 위에 상단 도구와 이동식 툴바를 배치한다.
    private func drawingSurface(size: CGSize) -> some View {
        FloorPlanCanvasView(
            canvasView: canvasView,
            tool: selectedTool.pencilKitTool
        )
        .overlay {
            if selectedTool == .hand {
                FloorPlanStrokeSelection(canvasView: canvasView)
            }
        }
        .overlay(alignment: .topLeading) {
            EditToolBar(selectedTool: $selectedEditTool, hiddenTools: [.roomName, .furniture, .door])
                .padding(8)
                .background {
                    Rectangle()
                        .fill(.white)
                        .gesture(DragGesture(minimumDistance: 0).onChanged { _ in })
                }
                .padding(Self.toolbarEdgeInset - 8)
        }
        .overlay {
            let anchor = toolbarPosition.anchor(in: size)
            drawingToolbar
                .position(x: anchor.x + toolbarDrag.width, y: anchor.y + toolbarDrag.height)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 8, coordinateSpace: .named("drawingSurface"))
                        .updating($toolbarDrag) { value, offset, _ in
                            offset = value.translation
                        }
                        .onEnded { value in
                            let destination = CGPoint(
                                x: anchor.x + value.translation.width,
                                y: anchor.y + value.translation.height
                            )
                            toolbarPosition = ToolbarPosition.allCases.min {
                                $0.distance(to: destination, in: size) <
                                    $1.distance(to: destination, in: size)
                            } ?? .bottom
                        }
                )
        }
        .coordinateSpace(name: "drawingSurface")
    }

    // 툴바 방향에 맞춰 펜·지우개·획 선택 버튼을 배열한다.
    private var drawingToolbar: some View {
        let layout = toolbarPosition == .bottom
            ? AnyLayout(HStackLayout(spacing: 4))
            : AnyLayout(VStackLayout(spacing: 4))

        return layout {
            ForEach(DrawingTool.allCases) { tool in
                toolButton(tool)
            }
        }
        .padding(Self.toolbarPadding)
        .glassEffect(.regular, in: Capsule())
        .contentShape(Capsule())
    }

    private func toolButton(_ tool: DrawingTool) -> some View {
        Button {
            selectedTool = tool
        } label: {
            Image(systemName: tool.icon)
                .frame(width: Self.toolSize, height: Self.toolSize)
                .background {
                    if selectedTool == tool {
                        Circle().fill(Color(red: 212.0 / 255, green: 212.0 / 255, blue: 214.0 / 255))
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tool.rawValue)
        .accessibilityAddTraits(selectedTool == tool ? .isSelected : [])
    }

    private enum DrawingTool: String, CaseIterable, Identifiable {
        case pen = "펜"
        case eraser = "지우개"
        case hand = "획 선택"

        var id: Self { self }

        var icon: String {
            switch self {
            case .pen: "pencil"
            case .eraser: "eraser"
            case .hand: "hand.point.up.left"
            }
        }

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

    // 드래그를 놓으면 툴바가 가장 가까운 가장자리에 붙는다.
    private enum ToolbarPosition: String, CaseIterable, Identifiable {
        case left = "왼쪽"
        case bottom = "하단"
        case right = "오른쪽"

        var id: Self { self }

        func anchor(in size: CGSize) -> CGPoint {
            let centerInset = FloorPlanDrawingView.toolbarEdgeInset
                + FloorPlanDrawingView.toolbarPadding + FloorPlanDrawingView.toolSize / 2

            switch self {
            case .left: return CGPoint(x: centerInset, y: size.height / 2)
            case .bottom: return CGPoint(x: size.width / 2, y: size.height - centerInset)
            case .right: return CGPoint(x: size.width - centerInset, y: size.height / 2)
            }
        }

        func distance(to point: CGPoint, in size: CGSize) -> CGFloat {
            let anchor = anchor(in: size)
            return hypot(point.x - anchor.x, point.y - anchor.y)
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
        canvas.drawingGestureRecognizer.isEnabled = tool != nil
    }
}

struct FloorPlanDrawingPreview: View {
    @State private var canvasView = PKCanvasView()

    var body: some View {
        NavigationStack {
            FloorPlanDrawingView(
                onRetake: {},
                onConfirm: {},
                canvasView: $canvasView
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

// 2D 도면 수정 화면. 도면을 화면에 맞춰 보여 주고 두 손가락으로 확대·축소하고 옮긴다.
// 스탬프는 도구로 놓고, 눌러 고르고, 끌어 옮긴다. 공간 이름은 눌러 고르고 끌어 옮기며, 고른 것을 한 번 더 누르면 키보드로 고친다. 창문·벽 수정은 이어서 들어온다

import SwiftUI

/// 2D 도면을 고치는 화면
struct FloorPlanEdit2DView: View {
    /// 2D·3D가 함께 보고 고치는 도면
    @Binding var planData: PlanData
    let onBack: () -> Void
    let onDone: () -> Void

    @State private var selectedTool: EditTool?
    /// 아래 막대에서 고른 펜·지우개·손. 손은 벽을 골라 옮길 때 쓴다
    // TEMP: 펜·지우개는 막대만 있고 아직 하는 일이 없음 — 할 일이 정해지면 연결
    @State private var drawingTool = DrawingTool.pen
    /// 도면이 화면에 놓인 배율과 자리. 화면 크기를 알게 되면 만든다
    @State private var screen: PlanScreen?
    /// 오므리는 동안 직전까지 적용한 배율. 바뀐 만큼만 screen에 곱한다
    @State private var lastMagnification = 1.0
    /// 고른 스탬프
    @State private var selection: PlanSelection?
    /// 고른 스탬프를 끄는 중이면, 끌기를 시작할 때 스탬프가 있던 도면 점
    @State private var stampDragStart: SIMD2<Double>?
    /// 스탬프를 끌거나 돌리는 동안 미리 보여 주는 도면. 손을 떼면 planData를 한 번만 바꾼다
    @State private var dragPreview: PlanData?
    /// 꾹 눌러 복제·삭제 메뉴를 띄운 스탬프. 다른 것을 고르거나 스탬프를 끌기 시작하면 사라진다
    @State private var menuTarget: PlanSelection?
    /// 지금 손가락이 닿아 있는 첫 화면 점. 꾹 누르기가 어느 스탬프 위였는지 알 때 쓴다 (꾹 누르기는 자리를 알려 주지 않아서)
    @State private var pressLocation: CGPoint?
    /// 한 번 눌러 고른 공간 이름 캡슐 (Room.id). 고른 캡슐만 끌어 옮기고, 한 번 더 누르면 이름을 고친다
    @State private var selectedRoomId: String?
    /// 이름을 고치는 중인 방 (Room.id)
    @State private var editingRoomId: String?
    /// 고치는 중인 이름. 끝낼 때 도면에 한 번 넣는다
    @State private var roomNameDraft = ""
    @FocusState private var isRoomNameFocused: Bool
    /// 공간 이름 캡슐을 끄는 중이면, 끌기를 시작할 때 캡슐이 있던 도면 점
    @State private var labelDragStart: SIMD2<Double>?
    /// 도면을 그리는 영역의 크기. 키보드에 가리지 않게 도면을 올릴 때 쓴다
    @State private var canvasSize: CGSize = .zero
    /// 이름 고치기 때문에 도면을 올리기 전 자리. 고치기를 끝내면 되돌린다
    @State private var screenBeforeEditing: PlanScreen?

    var body: some View {
        GeometryReader { proxy in
            planCanvas
                .onAppear { fitPlan(in: proxy.size) }
                .onChange(of: proxy.size) { _, size in fitPlan(in: size) }
        }
        // 처음 맞출 때 도면이 위·아래 도구 막대와 겹치지 않게 한다
        .padding(.vertical, Layout.toolBarInset)
        .background(.white)
        // 옮기거나 확대한 도면이 상단 바·상태 표시줄 위로 넘쳐 보이지 않게 이 영역 안에서만 그린다
        .clipped()
        .gesture(zoomGesture)
        .gesture(TwoFingerPanGesture(onChanged: panPlan))
        .overlay(alignment: .topLeading) {
            toolBar
        }
        .overlay {
            DrawingToolBar(selectedTool: $drawingTool)
        }
        .navigationTitle(Copy.title)
        .navigationBarTitleDisplayMode(.inline)
        .bothSidesToolbar(onBack: onBack, onDone: onDone)
        // 키보드가 올라와도 화면 크기가 바뀌지 않게 해서, 도면이 다시 맞춰지며 확대·이동이 풀리지 않게 한다
        .ignoresSafeArea(.keyboard)
    }

    /// 도면을 화면 크기에 맞춰 다시 놓는다
    private func fitPlan(in size: CGSize) {
        canvasSize = size
        screen = PlanScreen(plan: planData, in: size, fill: Layout.planFill)
    }
}

// 서브 뷰
extension FloorPlanEdit2DView {
    @ViewBuilder
    private var planCanvas: some View {
        if let screen {
            Plan2DView(
                planData: dragPreview ?? planData,
                screen: screen,
                selection: selection,
                editingRoomId: editingRoomId,
                selectedRoomId: selectedRoomId,
                roomLabelActions: RoomLabelActions(onTap: tapRoomLabel, onDrag: dragRoomLabel, onDragEnded: endRoomLabelDrag)
            )
                .contentShape(.rect)
                .gesture(tapGesture)
                .simultaneousGesture(stampDragGesture)
                .simultaneousGesture(longPressGesture)
                .simultaneousGesture(pressLocationGesture)
                .overlay(alignment: .topLeading) {
                    stampControls(screen: screen)
                }
                .overlay(alignment: .topLeading) {
                    openingControls(screen: screen)
                }
                .overlay(alignment: .topLeading) {
                    roomNameField(screen: screen)
                }
                .coordinateSpace(.named(Layout.planSpace))
                .onChange(of: selection) {
                    if menuTarget != selection { menuTarget = nil }
                }
        }
    }

    /// 고른 스탬프의 ✕·↻·↔ 손잡이, 또는 꾹 눌러 띄운 복제·삭제 메뉴
    @ViewBuilder
    private func stampControls(screen: PlanScreen) -> some View {
        let plan = dragPreview ?? planData
        if let selection, let point = stampPoint(of: selection, in: plan) {
            let center = screen.point(point)
            let marker = self.marker(of: selection, in: plan)
            let iconSize = marker.map(Plan2DView.iconSize(of:)) ?? Plan2DView.stampSize
            let halfSize = screen.length(iconSize) / 2 + Plan2DView.selectionPadding
            if menuTarget == selection {
                StampEditMenuView(
                    onDuplicate: { handleEdit(.duplicate(selection)) },
                    onDelete: { handleEdit(.delete(selection)) }
                )
                .position(x: center.x, y: center.y - halfSize - Layout.menuGap)
            } else {
                StampHandles2DView(
                    center: center,
                    halfSize: halfSize,
                    yaw: marker?.yaw,
                    scale: marker?.drawScale,
                    coordinateSpace: Layout.planSpace,
                    onDelete: { handleEdit(.delete(selection)) },
                    onRotate: { yaw in preview(selection) { .rotate(markerId: $0, yaw: yaw) } },
                    onResize: { scale in preview(selection) { .resize(markerId: $0, scale: scale) } },
                    onDragEnded: commitPreview
                )
            }
        }
    }

    private var toolBar: some View {
        EditToolBar(selectedTool: $selectedTool)
            .padding()
    }
}

// 누르기
extension FloorPlanEdit2DView {
    private var tapGesture: some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                guard let screen else { return }
                // 이름을 고치는 중에 다른 곳을 누르면 고치기만 끝낸다
                if editingRoomId != nil {
                    finishRoomEditing()
                    return
                }
                handleTap(screen.tap(at: value.location, in: planData))
            }
    }

    /// 이미 놓인 스탬프를 누르면 도구와 상관없이 그것을 고른다.
    /// 빈 곳은 스탬프 도구를 골랐으면 맞는 자리(발화지점·피해자는 바닥, 전기는 벽)에 놓고, 도구가 없으면 고른 것을 푼다.
    /// 공간라벨 도구로 방 안을 누르면 그 방 이름을 그 자리로 옮기고 바로 고친다.
    /// 도구는 놓은 뒤에도 켜져 있고, 방금 놓은 스탬프를 고른 상태로 둔다 (3D 수정 화면과 같다).
    /// 캡슐 밖을 누르면 고른 캡슐은 풀린다
    private func handleTap(_ tap: PlanTap) {
        selectedRoomId = nil
        switch (selectedTool, tap) {
        case (_, .element(let element)):
            selection = element
        case (nil, _):
            selection = nil
        case (.roomName?, .floor(let point)):
            guard let room = planData.room(containing: point) else { return }
            planData.moveRoomLabel(id: room.id, to: point)
            startRoomEditing(room.id)
        case (let tool?, _):
            selection = planData.place(tool, at: tap) ?? selection
        }
    }
}

// 공간 이름 고치기·옮기기
extension FloorPlanEdit2DView {
    /// 캡슐 자리에 이름 입력칸을 띄운다. 검은 캡슐 모양 그대로, 커서는 주황
    @ViewBuilder
    private func roomNameField(screen: PlanScreen) -> some View {
        if let editingRoomId, let room = planData.rooms.first(where: { $0.id == editingRoomId }) {
            TextField(room.name, text: $roomNameDraft)
                .font(AppTypography.subheadline)
                .foregroundStyle(.white)
                .tint(.brand500)
                .multilineTextAlignment(.center)
                .fixedSize()
                .padding(.horizontal, Layout.labelHorizontalPadding)
                .padding(.vertical, Layout.labelVerticalPadding)
                .background(.black, in: .capsule)
                .focused($isRoomNameFocused)
                .submitLabel(.done)
                .onSubmit(finishRoomEditing)
                .position(screen.point(SIMD2(room.labelX, room.labelY)))
        }
    }

    /// 캡슐을 한 번 누르면 스탬프처럼 고르고(주황 테두리), 고른 캡슐을 한 번 더 누르면 이름을 고친다
    private func tapRoomLabel(_ roomId: String) {
        if editingRoomId != nil {
            finishRoomEditing()
            return
        }
        if selectedRoomId == roomId {
            startRoomEditing(roomId)
        } else {
            selectedRoomId = roomId
            selection = nil
        }
    }

    /// 방 이름 고치기를 시작한다. 캡슐이 키보드에 가릴 자리면 도면을 위로 올린다
    private func startRoomEditing(_ roomId: String) {
        guard let room = planData.rooms.first(where: { $0.id == roomId }) else { return }
        selection = nil
        selectedRoomId = roomId
        roomNameDraft = room.name
        editingRoomId = roomId
        isRoomNameFocused = true
        if let screen {
            let labelY = screen.point(SIMD2(room.labelX, room.labelY)).y
            let visibleBottom = canvasSize.height * Layout.keyboardFreeShare
            if labelY > visibleBottom {
                screenBeforeEditing = screen
                withAnimation {
                    self.screen = screen.moved(by: CGSize(width: 0, height: visibleBottom - labelY))
                }
            }
        }
    }

    /// 고친 이름을 도면에 넣고 키보드를 내린다. 비워 두면 원래 이름이 남는다
    private func finishRoomEditing() {
        if let editingRoomId {
            planData.renameRoom(id: editingRoomId, to: roomNameDraft)
        }
        editingRoomId = nil
        isRoomNameFocused = false
        if let screenBeforeEditing {
            withAnimation { screen = screenBeforeEditing }
            self.screenBeforeEditing = nil
        }
    }

    /// 고른 캡슐을 끄는 동안은 미리 보기 도면에서만 옮긴다. 그 방 밖으로는 나가지 않는다. 고르지 않은 캡슐은 끌리지 않는다
    private func dragRoomLabel(_ roomId: String, translation: CGSize) {
        guard roomId == selectedRoomId, editingRoomId == nil, let screen, let room = planData.rooms.first(where: { $0.id == roomId }) else { return }
        let start = labelDragStart ?? SIMD2(room.labelX, room.labelY)
        labelDragStart = start
        let moved = screen.point(start)
        let point = screen.plan(CGPoint(x: moved.x + translation.width, y: moved.y + translation.height))
        var preview = dragPreview ?? planData
        preview.moveRoomLabel(id: roomId, to: point)
        dragPreview = preview
    }

    private func endRoomLabelDrag() {
        commitPreview()
        labelDragStart = nil
    }
}

// 스탬프 끌어 옮기기
// 끄는 동안은 미리 보기 도면만 바꾸고, 손을 뗄 때 planData를 한 번 바꾼다
extension FloorPlanEdit2DView {
    /// 고른 스탬프 위에서 시작한 한 손가락 끌기만 스탬프를 옮긴다. 다른 곳에서 시작한 끌기는 아무것도 하지 않는다
    private var stampDragGesture: some Gesture {
        DragGesture(minimumDistance: Layout.dragStartDistance)
            .onChanged { value in
                guard let screen, let selection else { return }
                if stampDragStart == nil {
                    guard screen.stamp(at: value.startLocation, in: planData) == selection else { return }
                    stampDragStart = stampPoint(of: selection)
                }
                guard let start = stampDragStart else { return }
                menuTarget = nil
                let point = start + screen.plan(value.location) - screen.plan(value.startLocation)
                // 방 밖으로 끌면 옮겨지지 않으므로, 직전 미리 보기에서 이어 가 마지막으로 놓을 수 있던 자리에 멈춰 있게 한다
                var preview = dragPreview ?? planData
                preview.moveStamp(selection, to: point)
                dragPreview = preview
            }
            .onEnded { _ in
                commitPreview()
                stampDragStart = nil
            }
    }

    /// 미리 보기 도면이 있으면 planData에 한 번 반영하고 지운다
    private func commitPreview() {
        if let dragPreview { planData = dragPreview }
        dragPreview = nil
    }

    /// 스탬프가 놓인 도면 점
    private func stampPoint(of selection: PlanSelection, in plan: PlanData? = nil) -> SIMD2<Double>? {
        let plan = plan ?? planData
        switch selection {
        case .marker(let id):
            return plan.markers.first { $0.id == id }?.position
        case .wallFixture(let id):
            return plan.wallFixtures.first { $0.id == id }.flatMap(plan.point(of:))
        case .doorWindow:
            return nil
        }
    }
}

// 스탬프 돌리기·복제·삭제
extension FloorPlanEdit2DView {
    /// 고른 것이 사람·발화지점이면 그 표시. 콘센트처럼 방향·크기가 없는 것은 nil
    private func marker(of selection: PlanSelection, in plan: PlanData) -> PlanMarker? {
        guard case .marker(let id) = selection else { return nil }
        return plan.markers.first { $0.id == id }
    }

    /// 돌리거나 크기를 바꾸는 동안은 미리 보기 도면만 바꾼다. edit는 표시 id로 바꿀 것을 만든다
    private func preview(_ selection: PlanSelection, _ edit: (String) -> PlanEdit) {
        guard case .marker(let id) = selection else { return }
        var preview = dragPreview ?? planData
        _ = preview.apply(edit(id), selection: selection)
        dragPreview = preview
    }

    /// 복제·삭제를 도면에 반영한다. 복제하면 새 것을, 지우면 아무것도 고르지 않은 상태로 둔다
    private func handleEdit(_ edit: PlanEdit) {
        selection = planData.apply(edit, selection: selection)
        menuTarget = nil
    }

    /// 스탬프 위를 꾹 누르면 그것을 고르고 복제·삭제 메뉴를 띄운다
    private var longPressGesture: some Gesture {
        LongPressGesture(minimumDuration: Layout.longPressDuration)
            .onEnded { _ in
                // 스탬프와 창문·문 모두 꾹 누르면 메뉴가 뜬다 (창문·문은 삭제만)
                guard let screen, let pressLocation,
                      case .element(let element) = screen.tap(at: pressLocation, in: planData) else { return }
                selectedRoomId = nil
                selection = element
                menuTarget = element
            }
    }

    /// 손가락이 처음 닿은 자리를 받아 둔다
    private var pressLocationGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if pressLocation == nil { pressLocation = value.startLocation }
            }
            .onEnded { _ in
                pressLocation = nil
            }
    }
}

// 창문·문 폭 바꾸기·지우기
extension FloorPlanEdit2DView {
    /// 고른 창문·문의 양 끝 손잡이, 또는 꾹 눌러 띄운 삭제 메뉴
    @ViewBuilder
    private func openingControls(screen: PlanScreen) -> some View {
        let plan = dragPreview ?? planData
        if case .doorWindow(let id)? = selection,
           let opening = plan.doorWindows.first(where: { $0.id == id }),
           let wall = plan.wall(id: opening.wallId), let line = plan.line(of: wall) {
            let start = screen.point(line.point(along: opening.centerAlongWall - opening.width / 2))
            let end = screen.point(line.point(along: opening.centerAlongWall + opening.width / 2))
            if menuTarget == selection {
                StampEditMenuView(onDuplicate: nil, onDelete: { handleEdit(.delete(.doorWindow(id))) })
                    .fixedSize()
                    .position(x: (start.x + end.x) / 2, y: min(start.y, end.y) - Layout.menuGap)
            } else {
                OpeningHandles2DView(
                    start: start,
                    end: end,
                    coordinateSpace: Layout.planSpace,
                    onDrag: { edge, location in previewOpeningEdge(id, edge: edge, at: location) },
                    onDragEnded: commitPreview
                )
            }
        }
    }

    /// 끄는 동안은 미리 보기 도면에서만 그 끝을 손가락이 있는 벽 위 자리로 옮긴다. 높이는 그대로 둔다
    private func previewOpeningEdge(_ id: String, edge: WindowEdge, at location: CGPoint) {
        guard let screen, let opening = planData.doorWindows.first(where: { $0.id == id }),
              let wall = planData.wall(id: opening.wallId), let line = planData.line(of: wall) else { return }
        let along = ((screen.plan(location) - line.start) * line.direction).sum()
        var preview = dragPreview ?? planData
        _ = preview.apply(.resizeWindow(id: id, edge: edge, along: along, height: opening.sillHeight), selection: selection)
        dragPreview = preview
    }
}

// 확대·축소
extension FloorPlanEdit2DView {
    /// 두 손가락 사이를 기준으로 확대·축소한다
    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                guard let screen else { return }
                let factor = value.magnification / lastMagnification
                lastMagnification = value.magnification
                self.screen = screen.zoomed(by: factor, around: value.startLocation)
            }
            .onEnded { _ in
                lastMagnification = 1
            }
    }

    /// 두 손가락으로 끈 만큼 도면을 옮긴다
    private func panPlan(to location: CGPoint, from previous: CGPoint) {
        screen = screen?.moved(by: CGSize(width: location.x - previous.x, height: location.y - previous.y))
    }
}

// 레이아웃 값
extension FloorPlanEdit2DView {
    private enum Layout {
        /// 처음 맞출 때 화면에서 도면이 차지하는 몫
        static let planFill = 0.85
        /// 도구 막대가 차지하는 위·아래 높이 (pt)
        static let toolBarInset: CGFloat = 90
        /// 이만큼(pt) 움직여야 끌기로 본다. 그보다 짧으면 누르기
        static let dragStartDistance: CGFloat = 4
        /// 편집 메뉴를 띄우는 꾹 누르기 시간 (초). 3D와 같다
        static let longPressDuration = 0.5
        /// 고른 테두리 위 변과 편집 메뉴 가운데 사이 (pt)
        static let menuGap: CGFloat = 36
        /// 손잡이를 끄는 거리를 재는 좌표 공간 이름 (도면 그림 전체)
        static let planSpace = "plan2D"
        /// 이름 입력칸의 안쪽 여백. RoomLabelView 캡슐과 같게 맞춘다
        static let labelHorizontalPadding: CGFloat = 14
        static let labelVerticalPadding: CGFloat = 6
        /// 키보드가 올라와도 가리지 않는 위쪽 몫. 이름 캡슐이 이보다 아래면 도면을 올린다
        static let keyboardFreeShare = 0.4
    }
}

// 문구
extension FloorPlanEdit2DView {
    private enum Copy {
        static let title = "도면 수정"
    }
}

#Preview {
    @Previewable @State var planData = DummyFloorPlan.planData

    NavigationStack {
        FloorPlanEdit2DView(planData: $planData, onBack: {}, onDone: {})
    }
}

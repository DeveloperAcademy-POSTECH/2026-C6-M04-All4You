// 2D 도면 수정 화면. 도면을 화면에 맞춰 보여 주고 두 손가락으로 확대·축소하고 옮긴다.
// 스탬프는 도구로 놓고, 눌러 고르고, 끌어 옮긴다. 공간 이름은 눌러 고르고 끌어 옮기며, 고른 것을 한 번 더 누르면 키보드로 고친다.
// 가구는 눌러 고르고, 끌어 옮기고, 손잡이로 돌리고 크기를 바꾸고 지운다. 가구 이름도 공간 이름처럼 두 번 눌러 고친다.
// 아래 막대의 펜으로 벽을 긋고, 지우개로 벽을 지우고, 손으로 벽을 골라 옮긴다

import SwiftUI

/// 2D 도면을 고치는 화면
struct FloorPlanEdit2DView: View {
    /// 2D·3D가 함께 보고 고치는 도면
    @Binding var planData: PlanData
    /// 3D 수정 화면과 함께 쓰는 되돌리기·다시 하기 기록
    @Binding var history: PlanHistory
    /// 위 도구 막대에서 켠 스탬프 도구. 2D·3D 전환 화면이 함께 들고 있어서 전환해도 이어진다
    @Binding var selectedTool: EditTool?
    let onBack: () -> Void
    let onDone: () -> Void

    /// 아래 막대에서 고른 펜·지우개·손. 펜은 벽을 그리고, 지우개는 벽을 지우고, 손은 벽을 골라 옮긴다
    @State private var drawingTool = DrawingTool.pen
    /// 펜으로 긋는 중인 선의 화면 시작·끝 점. 손을 떼면 이 선을 늘여 벽을 넣는다
    @State private var penStroke: (start: CGPoint, end: CGPoint)?
    /// 지우개로 문지르는 중인지
    @State private var isErasing = false
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
    /// 가구라벨 도구로 이름을 고치는 중인 가구 (Furniture.id)
    @State private var editingFurnitureId: String?
    /// 고치는 중인 가구 이름. 끝낼 때 도면에 한 번 넣는다
    @State private var furnitureLabelDraft = ""
    @FocusState private var isFurnitureLabelFocused: Bool
    /// 공간 이름 캡슐을 끄는 중이면, 끌기를 시작할 때 캡슐이 있던 도면 점
    @State private var labelDragStart: SIMD2<Double>?
    /// 도면을 그리는 영역의 크기. 키보드에 가리지 않게 도면을 올릴 때 쓴다
    @State private var canvasSize: CGSize = .zero
    /// 이름 고치기 때문에 도면을 올리기 전 자리. 고치기를 끝내면 되돌린다
    @State private var screenBeforeEditing: PlanScreen?
    /// 손 도구로 고른 벽 묶음 (일직선 줄 전체 또는 한 구간). 비스듬한 벽을 고르면 nil
    @State private var wallSelection: WallSelection?
    /// 벽을 끌기 시작할 때의 도면과 이동 범위. 끄는 내내 이 도면에 이동량을 더해 계산한다
    @State private var wallDragBase: (plan: PlanData, limits: MoveLimits)?
    /// 벽이 범위 끝에 막혔을 때 보여 줄 이유
    @State private var wallBlockedReason: String?
    /// 안내를 일정 시간 뒤 내리는 작업. 새 안내가 뜨면 이전 것을 취소한다
    @State private var noticeDismissTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { proxy in
            planCanvas
                // 도면을 맞추기 전에는 planCanvas가 비어 있어 onAppear가 불리지 않을 수 있다. 그래서 처음 크기도 initial: true로 받는다
                .onChange(of: proxy.size, initial: true) { _, size in fitPlan(in: size) }
        }
        // 위 도구 막대가 리퀴드 글래스라 도면이 그 밑으로 비쳐 보인다 (3D와 같다). 처음 맞출 때만 막대를 피해 놓는다
        .background(.white)
        .gesture(zoomGesture)
        .gesture(TwoFingerPanGesture(onChanged: panPlan))
        .overlay(alignment: .topLeading) {
            toolBar
        }
        .overlay {
            DrawingToolBar(selectedTool: $drawingTool, bottomInset: Layout.drawingBarBottomInset, isPenAndEraserSuspended: isStampActive, onSelect: pickDrawingTool)
        }
        .bothSidesToolbar(customLayout: true, barTitle: Copy.title, trailingAccessory: AnyView(undoRedo), onBack: onBack, onDone: onDone)
        // 키보드가 올라와도 화면 크기가 바뀌지 않게 해서, 도면이 다시 맞춰지며 확대·이동이 풀리지 않게 한다
        .ignoresSafeArea(.keyboard)
    }

    /// 도면을 화면 크기에 맞춰 다시 놓는다
    private func fitPlan(in size: CGSize) {
        canvasSize = size
        // 위·아래 막대를 뺀 영역 가운데에 맞춘 뒤 아래로 내려, 처음에는 도면이 막대와 겹치지 않게 한다
        let inner = CGSize(width: size.width, height: max(size.height - Layout.toolBarInset * 2, 1))
        screen = PlanScreen(plan: planData, in: inner, fill: Layout.planFill)
            .moved(by: CGSize(width: 0, height: Layout.toolBarInset))
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
                selectedWallIds: wallSelection?.wallIds ?? [],
                roomLabelActions: roomLabelActions,
                editingFurnitureId: editingFurnitureId,
                onTapFurnitureLabel: furnitureLabelTap
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
                .overlay(alignment: .topLeading) {
                    furnitureLabelField(screen: screen)
                }
                .coordinateSpace(.named(Layout.planSpace))
                .onChange(of: selection) {
                    if menuTarget != selection { menuTarget = nil }
                    if case .wall? = selection {} else { wallSelection = nil }
                }
                .overlay(alignment: .top) {
                    wallBlockedNotice
                }
                .overlay {
                    penStrokeLine
                }
        }
    }

    /// 고른 스탬프·가구의 ✕·↻·↔ 손잡이, 또는 꾹 눌러 띄운 복제·삭제 메뉴
    @ViewBuilder
    private func stampControls(screen: PlanScreen) -> some View {
        let plan = dragPreview ?? planData
        if let selection, let point = stampPoint(of: selection, in: plan) {
            let center = screen.point(point)
            let marker = self.marker(of: selection, in: plan)
            let halfSize = handleHalfSize(of: selection, in: plan, screen: screen)
            if menuTarget == selection {
                StampEditMenuView(
                    onDuplicate: { handleEdit(.duplicate(selection)) },
                    onDelete: { handleEdit(.delete(selection)) }
                )
                .position(x: center.x, y: center.y - halfSize.height - Layout.menuGap)
            } else {
                StampHandles2DView(
                    center: center,
                    halfSize: halfSize,
                    yaw: handleYaw(of: selection, in: plan),
                    scale: marker?.drawScale,
                    coordinateSpace: Layout.planSpace,
                    onDelete: { handleEdit(.delete(selection)) },
                    onRotate: { yaw in rotateEdit(of: selection, yaw: yaw).map(preview) },
                    onResize: { scale in
                        if let marker { preview(.resize(markerId: marker.id, scale: scale)) }
                    },
                    onDragEnded: endHandleDrag,
                    onResizeCorner: furniture(of: selection, in: planData).map { furniture in
                        { location in resizeFurniture(furniture, cornerAt: location, screen: screen) }
                    }
                )
            }
        }
    }

    private var toolBar: some View {
        // 위 도구(스탬프·라벨·창문·문)는 아래 막대가 펜·지우개·손 어느 것이어도 쓸 수 있고, 켜 두면 아래 동작보다 먼저 처리된다
        EditToolBar(selectedTool: $selectedTool)
            .padding()
            .onChange(of: selectedTool) {
                // 도구를 켜면 고른 벽은 풀어 둔다 (도구가 켜진 동안은 벽을 고르거나 옮기지 않는다)
                if selectedTool != nil, case .wall? = selection { selection = nil }
            }
    }

    /// 아래 막대에서 도구를 눌렀다. 펜·지우개를 쓰려는 것이므로 위 도구와 고른 스탬프·이름 캡슐을 모두 푼다.
    /// 이미 고른 펜을 다시 눌러도 값이 안 바뀌어 onChange로는 알 수 없어서 막대가 누른 것을 알려 준다
    private func pickDrawingTool(_ tool: DrawingTool) {
        guard tool != .hand else { return }
        selectedTool = nil
        selection = nil
        selectedRoomId = nil
        menuTarget = nil
    }

    /// 공간 이름 캡슐 누르기·끌기. 펜·지우개일 때는 nil이라 캡슐을 누르거나 끌 수 없다 (위 도구가 켜져 있으면 쓸 수 있다)
    private var roomLabelActions: RoomLabelActions? {
        guard canUseStamps else { return nil }
        return RoomLabelActions(onTap: tapRoomLabel, onDrag: dragRoomLabel, onDragEnded: endRoomLabelDrag, onDelete: deleteRoomLabel)
    }

    /// 가구 이름 캡슐 누르기. 펜·지우개일 때는 nil이라 누를 수 없다
    private var furnitureLabelTap: ((String) -> Void)? {
        guard canUseStamps else { return nil }
        return { tapFurnitureLabel($0) }
    }

    /// 아래 막대가 획 선택(손)인지. 위 도구와 스탬프·라벨 상호작용은 이때만 된다
    private var isHandTool: Bool {
        drawingTool == .hand
    }

    /// 위 도구(스탬프·라벨·창문·문)를 켜 두었는지. 켜 두면 아래 막대가 무엇이든 스탬프 동작이 먼저다
    private var isStampActive: Bool {
        selectedTool != nil
    }

    /// 스탬프·라벨·창문·문과 상호작용할 수 있는지: 손 도구이거나 위 도구가 켜져 있을 때
    private var canUseStamps: Bool {
        isHandTool || isStampActive
    }

    /// 되돌리면 고른 것이 사라졌을 수 있어 고르기·메뉴·미리 보기를 비운다. 고치던 이름은 넣지 않고 닫는다
    private var undoRedo: some View {
        UndoRedoCapsule(history: $history, planData: $planData) {
            editingRoomId = nil
            isRoomNameFocused = false
            editingFurnitureId = nil
            isFurnitureLabelFocused = false
            selection = nil
            selectedRoomId = nil
            menuTarget = nil
            dragPreview = nil
        }
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
                if editingFurnitureId != nil {
                    finishFurnitureEditing()
                    return
                }
                // 발화지점·피해자 도구는 문이 열리는 자리에도 놓을 수 있게, 부채꼴 안을 문으로 치지 않는다
                let isPlacingOnFloor = selectedTool == .ignitionPoint || selectedTool == .person
                handleTap(screen.tap(at: value.location, in: planData, includesDoorSwing: !isPlacingOnFloor))
            }
    }

    /// 이미 놓인 스탬프를 누르면 도구와 상관없이 그것을 고른다.
    /// 빈 곳은 스탬프 도구를 골랐으면 맞는 자리(발화지점·피해자는 바닥, 전기는 벽)에 놓고, 도구가 없으면 그 아래 가구를 고르거나 고른 것을 푼다.
    /// 그래서 도구를 고른 채 가구 위를 누르면 가구를 고르지 않고 그 자리에 스탬프를 놓는다 (침대 위 발화지점 등).
    /// 공간라벨 도구로 방 안을 누르면 그 방 이름을 그 자리로 옮기고 바로 고친다. 이름 없는 닫힌 칸을 누르면 거기에 새 공간 이름을 달고 바로 고친다. 고른 이름은 ✕로 지운다. 가구라벨 도구로 가구를 누르면 고르고, 고른 가구를 한 번 더 누르면 이름을 고친다. 가구가 없는 바닥을 누르면 새 가구를 놓고 바로 이름을 고친다.
    /// 도구는 놓은 뒤에도 켜져 있고, 방금 놓은 스탬프를 고른 상태로 둔다 (3D 수정 화면과 같다).
    /// 캡슐 밖을 누르면 고른 캡슐은 풀린다
    private func handleTap(_ tap: PlanTap) {
        selectedRoomId = nil
        // 펜·지우개이고 위 도구도 꺼져 있으면 스탬프·라벨·창문·문·가구와 상호작용하지 않는다. 지우개로 벽을 누르면 그 벽만 지운다
        guard canUseStamps else {
            if drawingTool == .eraser, case .wall(let id, _, _) = tap {
                planData.eraseWall(id: id)
            }
            selection = nil
            return
        }
        // 획 선택에서 위 도구를 고르지 않았으면 벽·스탬프·가구를 고른다
        if selectedTool == nil {
            handleHandTap(tap)
            return
        }
        switch (selectedTool, tap) {
        case (_, .element(let element)):
            selection = element
        case (nil, .floor(let point)):
            selection = furnitureSelection(at: point)
        case (nil, _):
            selection = nil
        case (.roomName?, .floor(let point)):
            if planData.room(containing: point) != nil {
                // 닫힌 공간 하나에는 라벨 하나만 둘 수 있다. 라벨 자리는 라벨을 끌어 옮긴다
                showNotice(Copy.roomLabelExists)
            } else if let newId = planData.addRoom(at: point) {
                // 이름 없는 닫힌 칸이면 새 공간 이름을 달고 바로 고친다
                startRoomEditing(newId)
            } else {
                showNotice(Copy.roomNotClosed)
            }
        case (.furniture?, .floor(let point)):
            if let furniture = planData.furniture(at: point) {
                selectOrEditFurniture(furniture.id)
            } else if let newId = planData.addFurniture(at: point) {
                startFurnitureEditing(newId)
            }
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
        liftAboveKeyboard(SIMD2(room.labelX, room.labelY))
    }

    /// 입력칸 자리(도면 점)가 키보드에 가릴 자리면 도면을 위로 올린다. 고치기를 끝내면 restoreAfterKeyboard로 되돌린다
    private func liftAboveKeyboard(_ point: SIMD2<Double>) {
        guard let screen else { return }
        let labelY = screen.point(point).y
        let visibleBottom = canvasSize.height * Layout.keyboardFreeShare
        if labelY > visibleBottom {
            screenBeforeEditing = screen
            withAnimation {
                self.screen = screen.moved(by: CGSize(width: 0, height: visibleBottom - labelY))
            }
        }
    }

    /// 이름 고치기 때문에 올린 도면을 제자리로
    private func restoreAfterKeyboard() {
        if let screenBeforeEditing {
            withAnimation { screen = screenBeforeEditing }
            self.screenBeforeEditing = nil
        }
    }

    /// 고친 이름을 도면에 넣고 키보드를 내린다. 비워 두면 원래 이름이 남는다
    private func finishRoomEditing() {
        if let editingRoomId {
            planData.renameRoom(id: editingRoomId, to: roomNameDraft)
        }
        editingRoomId = nil
        isRoomNameFocused = false
        restoreAfterKeyboard()
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

    /// 고른 공간 이름을 지운다. 벽은 그대로라 그 칸은 이름 없는 칸이 되고, 공간라벨 도구로 다시 달 수 있다
    private func deleteRoomLabel(_ roomId: String) {
        planData.removeRoom(id: roomId)
        selectedRoomId = nil
    }

    private func endRoomLabelDrag() {
        commitPreview()
        labelDragStart = nil
    }
}

// 가구 이름 고치기
extension FloorPlanEdit2DView {
    /// 가구 이름 캡슐 자리에 입력칸을 띄운다. 흰 캡슐·검은 테두리 모양 그대로, 커서는 주황
    @ViewBuilder
    private func furnitureLabelField(screen: PlanScreen) -> some View {
        if let editingFurnitureId, let furniture = planData.furniture?.first(where: { $0.id == editingFurnitureId }) {
            TextField(furniture.label, text: $furnitureLabelDraft)
                .font(AppTypography.label)
                .foregroundStyle(.black)
                .tint(.brand500)
                .multilineTextAlignment(.center)
                .fixedSize()
                .padding(.horizontal, Layout.furnitureLabelHorizontalPadding)
                .padding(.vertical, Layout.furnitureLabelVerticalPadding)
                .background(.white, in: .capsule)
                .overlay { Capsule().stroke(.black, lineWidth: 1) }
                .focused($isFurnitureLabelFocused)
                .submitLabel(.done)
                .onSubmit(finishFurnitureEditing)
                .position(screen.point(furniture.center))
        }
    }

    /// 가구 이름 캡슐을 누르면 펜·지우개·획 선택이나 위 도구와 상관없이 공간 이름처럼 다룬다: 한 번은 고르고(주황), 고른 것을 한 번 더 누르면 고친다
    private func tapFurnitureLabel(_ furnitureId: String) {
        if editingRoomId != nil {
            finishRoomEditing()
            return
        }
        if editingFurnitureId != nil {
            finishFurnitureEditing()
            return
        }
        selectOrEditFurniture(furnitureId)
    }

    /// 고르지 않은 가구면 고르고, 이미 고른 가구면 이름 고치기를 시작한다
    private func selectOrEditFurniture(_ furnitureId: String) {
        selectedRoomId = nil
        if selection == .furniture(furnitureId) {
            startFurnitureEditing(furnitureId)
        } else {
            selection = .furniture(furnitureId)
        }
    }

    private func startFurnitureEditing(_ furnitureId: String) {
        guard let furniture = planData.furniture?.first(where: { $0.id == furnitureId }) else { return }
        selection = nil
        selectedRoomId = nil
        furnitureLabelDraft = furniture.label
        editingFurnitureId = furnitureId
        isFurnitureLabelFocused = true
        liftAboveKeyboard(furniture.center)
    }

    /// 고친 이름을 도면에 넣고 키보드를 내린다. 비워 두면 원래 이름이 남는다
    private func finishFurnitureEditing() {
        if let editingFurnitureId {
            planData.renameFurniture(id: editingFurnitureId, to: furnitureLabelDraft)
        }
        editingFurnitureId = nil
        isFurnitureLabelFocused = false
        restoreAfterKeyboard()
    }
}

// 스탬프·가구 끌어 옮기기
// 끄는 동안은 미리 보기 도면만 바꾸고, 손을 뗄 때 planData를 한 번 바꾼다
extension FloorPlanEdit2DView {
    /// 고른 스탬프·가구 위에서 시작한 한 손가락 끌기만 그것을 옮긴다. 다른 곳에서 시작한 끌기는 아무것도 하지 않는다
    private var stampDragGesture: some Gesture {
        DragGesture(minimumDistance: Layout.dragStartDistance)
            .onChanged { value in
                guard let screen else { return }
                if drawOrErase(value, screen: screen) { return }
                guard let selection else { return }
                if dragWall(value, screen: screen) { return }
                if stampDragStart == nil {
                    guard startsOnSelection(value.startLocation, screen: screen) else { return }
                    stampDragStart = stampPoint(of: selection)
                }
                guard let start = stampDragStart else { return }
                menuTarget = nil
                let point = start + screen.plan(value.location) - screen.plan(value.startLocation)
                // 방 밖으로 끌면 옮겨지지 않으므로, 직전 미리 보기에서 이어 가 마지막으로 놓을 수 있던 자리에 멈춰 있게 한다
                var preview = dragPreview ?? planData
                preview.moveStamp(selection, to: point)
                dragPreview = preview
                showFurnitureBlocked(furniture(of: selection, in: preview).map { $0.center != point } ?? false)
            }
            .onEnded { _ in
                commitPreview()
                finishPenStroke()
                isErasing = false
                stampDragStart = nil
                wallDragBase = nil
                wallBlockedReason = nil
            }
    }

    /// 미리 보기 도면이 있으면 planData에 한 번 반영하고 지운다
    private func commitPreview() {
        if let dragPreview { planData = dragPreview }
        dragPreview = nil
    }

    /// 스탬프가 놓인 도면 점. 가구는 가운데
    private func stampPoint(of selection: PlanSelection, in plan: PlanData? = nil) -> SIMD2<Double>? {
        let plan = plan ?? planData
        switch selection {
        case .marker(let id):
            return plan.markers.first { $0.id == id }?.position
        case .wallFixture(let id):
            return plan.wallFixtures.first { $0.id == id }.flatMap(plan.point(of:))
        case .furniture:
            return furniture(of: selection, in: plan)?.center
        case .doorWindow, .wall:
            return nil
        }
    }
}

// 펜으로 벽 그리기·지우개로 벽 지우기
// 고른 스탬프·벽을 끄는 중이 아니면, 펜 끌기는 벽 한 줄을 긋고 지우개 끌기는 손가락이 지나간 벽을 지운다.
// 끄는 동안은 미리 보기 도면만 바꾸므로 한 번 긋거나 문지른 것이 되돌리기 한 칸이다
extension FloorPlanEdit2DView {
    /// 펜·지우개 끌기를 처리했으면 true
    private func drawOrErase(_ value: DragGesture.Value, screen: PlanScreen) -> Bool {
        let isNewStroke = penStroke == nil && !isErasing
        if isNewStroke {
            // 고른 스탬프·벽 위에서 시작했거나 공간 이름을 끄는 중이면 그것을 옮긴다
            guard drawingTool != .hand, !isStampActive, stampDragStart == nil, wallDragBase == nil, labelDragStart == nil,
                  selection == nil || !startsOnSelection(value.startLocation, screen: screen) else { return false }
            selection = nil
            menuTarget = nil
        }
        switch drawingTool {
        case .pen:
            penStroke = (value.startLocation, value.location)
        case .eraser:
            isErasing = true
            var preview = dragPreview ?? planData
            if case .wall(let id, _, _) = screen.tap(at: value.location, in: preview) {
                preview.eraseWall(id: id)
                dragPreview = preview
            }
        case .hand:
            return false
        }
        return true
    }

    /// 그은 선을 양쪽으로 늘여 처음 닿는 벽 사이에 벽을 넣는다. 넣을 수 없는 자리면 아무것도 바꾸지 않는다
    private func finishPenStroke() {
        guard let penStroke, let screen else { return }
        self.penStroke = nil
        if let drawn = planData.drawingWall(
            from: screen.plan(penStroke.start),
            to: screen.plan(penStroke.end),
            snapRadius: Double(Layout.snapDistance) / Double(screen.length(1))
        ) {
            planData = drawn
        }
    }

    /// 화면 점이 고른 스탬프·벽·가구 위인지. 가구는 다른 가구와 겹쳐 아래에 있어도 고른 가구 안이면 맞다
    private func startsOnSelection(_ location: CGPoint, screen: PlanScreen) -> Bool {
        switch screen.tap(at: location, in: planData) {
        case .element(let element):
            return element == selection
        case .wall(let id, _, _):
            return selection == .wall(id) || wallSelection?.wallIds.contains(id) == true
        case .floor(let point):
            return selection.flatMap { furniture(of: $0, in: planData) }?.contains(point) == true
        }
    }

    /// 펜으로 긋는 중인 선. 손을 떼기 전까지는 손가락이 그은 그대로 보여 준다
    @ViewBuilder
    private var penStrokeLine: some View {
        if let penStroke {
            Path { path in
                path.move(to: penStroke.start)
                path.addLine(to: penStroke.end)
            }
            .stroke(Color.brand500, style: StrokeStyle(lineWidth: Layout.penLineWidth, lineCap: .round, dash: Layout.penDash))
            .allowsHitTesting(false)
        }
    }
}

// 벽 고르기·옮기기
// 손 도구일 때만 벽을 고른다. 한 번 누르면 일직선으로 이어진 줄 전체, 고른 벽을 다시 누르면 그 구간만 고른다.
// 고른 벽을 끌면 가로 벽은 위아래로, 세로 벽은 좌우로만 옮기고, 다른 벽에 너무 가까워지거나 벽이 너무 짧아지면 멈춘다.
// 비스듬한 벽은 줄로 묶지 않고 벽과 수직으로만 평행 이동한다
extension FloorPlanEdit2DView {
    /// 손 도구로 누른 곳이 벽이면 그 벽을 고른다. 창문·문·스탬프는 도구와 상관없이 그것을 고르고, 바닥은 그 아래 가구를 고른다
    private func handleHandTap(_ tap: PlanTap) {
        switch tap {
        case .element(let element):
            selection = element
        case .wall(let id, _, _):
            if case .wall? = selection, let current = wallSelection, current.wallIds.contains(id) {
                // 고른 벽을 다시 누르면 줄 전체 ↔ 이 구간만
                wallSelection = current.isWholeLine ? planData.wallSegment(id) : planData.wallLine(containing: id)
            } else {
                wallSelection = planData.wallLine(containing: id)
            }
            selection = .wall(id)
        case .floor(let point):
            selection = furnitureSelection(at: point)
        }
    }

    /// 고른 벽 위에서 시작한 끌기면 벽을 옮긴다. 옮겼으면 true
    private func dragWall(_ value: DragGesture.Value, screen: PlanScreen) -> Bool {
        guard case .wall(let id)? = selection,
              case .wall(let startId, _, _) = screen.tap(at: value.startLocation, in: wallDragBase?.plan ?? planData),
              startId == id || wallSelection?.wallIds.contains(startId) == true else { return false }
        menuTarget = nil
        let moved = screen.plan(value.location) - screen.plan(value.startLocation)
        guard let wallSelection else {
            // 비스듬한 벽: 그 벽만 수직으로 평행 이동하고 다른 벽은 제자리. 막히면 마지막으로 맞는 미리 보기를 두고 위쪽에 이유를 띄운다
            guard let wall = planData.wall(id: id), let line = planData.line(of: wall) else { return true }
            switch planData.movingSlantedWall(id: id, by: (moved * line.leftNormal).sum()) {
            case .success(let next):
                dragPreview = next
                wallBlockedReason = nil
            case .failure(let block):
                wallBlockedReason = block.message
            }
            return true
        }
        let base = wallDragBase ?? (planData, planData.moveLimits(wallSelection))
        wallDragBase = base
        let resolved = base.limits.resolve(moved[wallSelection.axis.across])
        wallBlockedReason = resolved.blockedBy
        // 도면이 깨지는 자리면 마지막으로 맞는 미리 보기를 그대로 둔다
        if let next = base.plan.movingWalls(wallSelection, by: resolved.delta) {
            dragPreview = next
        }
        return true
    }

    /// 벽이 범위 끝에 막혔을 때 위쪽에 잠깐 보여 주는 이유
    @ViewBuilder
    private var wallBlockedNotice: some View {
        if let wallBlockedReason {
            Text(wallBlockedReason)
                .font(AppTypography.subheadline)
                .foregroundStyle(.white)
                .padding(.horizontal, Layout.labelHorizontalPadding)
                .padding(.vertical, Layout.labelVerticalPadding)
                .background(Color.gray900, in: .capsule)
                .padding(.top, Layout.noticeTopPadding)
        }
    }
}

// 스탬프·가구 돌리기·복제·삭제
extension FloorPlanEdit2DView {
    /// 고른 것이 사람·발화지점이면 그 표시. 콘센트처럼 방향·크기가 없는 것은 nil
    private func marker(of selection: PlanSelection, in plan: PlanData) -> PlanMarker? {
        guard case .marker(let id) = selection else { return nil }
        return plan.markers.first { $0.id == id }
    }

    /// 고른 것이 가구면 그 가구
    private func furniture(of selection: PlanSelection, in plan: PlanData) -> Furniture? {
        guard case .furniture(let id) = selection else { return nil }
        return plan.furniture?.first { $0.id == id }
    }

    /// 도면 점 아래 가구를 고른 값. 가구가 없으면 nil (고른 것을 푼다)
    private func furnitureSelection(at point: SIMD2<Double>) -> PlanSelection? {
        planData.furniture(at: point).map { .furniture($0.id) }
    }

    /// 손잡이를 붙일 테두리의 가운데에서 변까지 (pt). 스탬프는 아이콘 정사각형, 가구는 가구 가로·세로에 여백을 더한다
    private func handleHalfSize(of selection: PlanSelection, in plan: PlanData, screen: PlanScreen) -> CGSize {
        let padding = Plan2DView.selectionPadding
        if let furniture = furniture(of: selection, in: plan) {
            return CGSize(width: screen.length(furniture.width / 2) + padding, height: screen.length(furniture.depth / 2) + padding)
        }
        let iconSize = marker(of: selection, in: plan).map { Plan2DView.iconSize(of: $0) } ?? Plan2DView.stampSize
        let half = screen.length(iconSize) / 2 + padding
        return CGSize(width: half, height: half)
    }

    /// 손잡이가 따라 돌 방향 (도). 돌릴 수 없는 것(콘센트)은 nil
    private func handleYaw(of selection: PlanSelection, in plan: PlanData) -> Double? {
        marker(of: selection, in: plan)?.yaw
            ?? furniture(of: selection, in: plan).map { $0.rotation * 180 / .pi }
    }

    /// 손잡이로 돌린 방향(도)을 도면에 넣을 값으로. 가구는 라디안으로 바꾼다
    private func rotateEdit(of selection: PlanSelection, yaw: Double) -> PlanEdit? {
        switch selection {
        case .marker(let id): .rotate(markerId: id, yaw: yaw)
        case .furniture(let id): .rotateFurniture(id: id, rotation: yaw * .pi / 180)
        case .wallFixture, .doorWindow, .wall: nil
        }
    }

    /// 돌리거나 크기를 바꾸는 동안은 미리 보기 도면만 바꾼다
    private func preview(_ edit: PlanEdit) {
        var preview = dragPreview ?? planData
        _ = preview.apply(edit, selection: selection)
        dragPreview = preview
        if case .rotateFurniture(let id, let rotation) = edit {
            showFurnitureBlocked(preview.furniture?.first { $0.id == id }.map { $0.rotation != rotation } ?? false)
        }
    }

    /// 크기 손잡이가 손가락 자리에 오도록 가로·세로를 바꾼다. 가운데는 그대로라 양쪽이 함께 늘고 준다.
    /// 손가락 자리를 가구 방향으로 되돌려 가로·세로 거리를 재고, 손잡이가 테두리 여백만큼 바깥에 있으니 그만큼 뺀다
    private func resizeFurniture(_ furniture: Furniture, cornerAt location: CGPoint, screen: PlanScreen) {
        let offset = screen.plan(location) - furniture.center
        let across = abs(offset.x * cos(furniture.rotation) + offset.y * sin(furniture.rotation))
        let along = abs(-offset.x * sin(furniture.rotation) + offset.y * cos(furniture.rotation))
        let padding = Double(Plan2DView.selectionPadding) / Double(screen.length(1))
        let width = max((across - padding) * 2, Furniture.minSize)
        let depth = furniture.shape == .circle ? width : max((along - padding) * 2, Furniture.minSize)
        var next = dragPreview ?? planData
        next.resizeFurniture(id: furniture.id, width: width, depth: depth)
        dragPreview = next
        let resized = next.furniture?.first { $0.id == furniture.id }
        showFurnitureBlocked(resized.map { $0.width != width || $0.depth != depth } ?? false)
    }

    /// 가구가 벽에 막혀 손가락을 따라가지 못하면 위쪽에 이유를 띄우고, 다시 따라가면 내린다 (벽이 막힐 때와 같은 캡슐)
    private func showFurnitureBlocked(_ isBlocked: Bool) {
        wallBlockedReason = isBlocked ? Copy.furnitureBlocked : nil
    }

    /// 위쪽 캡슐로 안내를 잠깐 띄운다. 끄는 동안 계속 보여야 하는 막힘 안내와 달리 시간이 지나면 스스로 내려간다
    private func showNotice(_ text: String) {
        wallBlockedReason = text
        noticeDismissTask?.cancel()
        noticeDismissTask = Task {
            try? await Task.sleep(for: Layout.noticeDuration)
            if !Task.isCancelled, wallBlockedReason == text { wallBlockedReason = nil }
        }
    }

    /// 돌리기·크기 바꾸기에서 손을 떼면 미리 보기를 반영하고 막힘 안내를 내린다
    private func endHandleDrag() {
        commitPreview()
        wallBlockedReason = nil
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
                guard canUseStamps, let screen, let pressLocation else { return }
                let target: PlanSelection
                switch screen.tap(at: pressLocation, in: planData) {
                case .element(let element):
                    target = element
                default:
                    return
                }
                selectedRoomId = nil
                selection = target
                menuTarget = target
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
        /// 아래 2D·3D 전환 막대에 가리지 않게 펜·지우개·손 막대를 올릴 높이 (pt). 전환 막대 높이 + 바깥 여백 + 사이 여백
        static let drawingBarBottomInset: CGFloat = 50 + 16 + 12
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
        /// 가구 이름 입력칸의 안쪽 여백. FurnitureLabelView 캡슐과 같게 맞춘다
        static let furnitureLabelHorizontalPadding: CGFloat = 10
        static let furnitureLabelVerticalPadding: CGFloat = 4
        /// 키보드가 올라와도 가리지 않는 위쪽 몫. 이름 캡슐이 이보다 아래면 도면을 올린다
        static let keyboardFreeShare = 0.4
        /// 벽이 막힌 이유를 도면 영역 위 끝에서 얼마나 내려 보여 줄지 (pt)
        static let noticeTopPadding: CGFloat = 8
        /// 안내 캡슐이 떠 있는 시간
        static let noticeDuration = Duration.seconds(2)
        /// 펜 끝을 꼭짓점·벽에 붙이는 거리 (pt)
        static let snapDistance: CGFloat = 16
        /// 긋는 중인 펜 점선
        static let penLineWidth: CGFloat = 2
        static let penDash: [CGFloat] = [6, 4]
    }
}

// 문구
extension FloorPlanEdit2DView {
    private enum Copy {
        static let title = "도면 수정"
        static let furnitureBlocked = "벽에 막혀 더 움직일 수 없어요"
        // TEMP: Figma에 안내 문구가 없어 임의로 작성 — 디자인 확인 필요
        static let roomLabelExists = "닫힌 공간 하나에는 라벨을 하나만 만들 수 있어요"
        static let roomNotClosed = "벽으로 닫힌 공간에만 라벨을 만들 수 있어요"
    }
}

#Preview {
    @Previewable @State var planData = DummyFloorPlan.planData
    @Previewable @State var history = PlanHistory()
    @Previewable @State var selectedTool: EditTool?

    NavigationStack {
        FloorPlanEdit2DView(planData: $planData, history: $history, selectedTool: $selectedTool, onBack: {}, onDone: {})
    }
}

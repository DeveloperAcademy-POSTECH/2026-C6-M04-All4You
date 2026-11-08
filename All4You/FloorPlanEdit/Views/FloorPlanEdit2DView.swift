// 2D 도면 수정 화면. 도면을 화면에 맞춰 보여 주고 두 손가락으로 확대·축소하고 옮긴다.
// 스탬프는 도구로 놓고, 눌러 고르고, 끌어 옮긴다. 공간 이름·창문·벽 수정은 이어서 들어온다

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

    var body: some View {
        GeometryReader { proxy in
            planCanvas
                .onAppear { fitPlan(in: proxy.size) }
                .onChange(of: proxy.size) { _, size in fitPlan(in: size) }
        }
        // 처음 맞출 때 도면이 위·아래 도구 막대와 겹치지 않게 한다
        .padding(.vertical, Layout.toolBarInset)
        .background(.white)
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
    }

    /// 도면을 화면 크기에 맞춰 다시 놓는다
    private func fitPlan(in size: CGSize) {
        screen = PlanScreen(plan: planData, in: size, fill: Layout.planFill)
    }
}

// 서브 뷰
extension FloorPlanEdit2DView {
    @ViewBuilder
    private var planCanvas: some View {
        if let screen {
            Plan2DView(planData: dragPreview ?? planData, screen: screen, selection: selection)
                .contentShape(.rect)
                .gesture(tapGesture)
                .simultaneousGesture(stampDragGesture)
                .simultaneousGesture(longPressGesture)
                .simultaneousGesture(pressLocationGesture)
                .overlay(alignment: .topLeading) {
                    stampControls(screen: screen)
                }
                .coordinateSpace(.named(Layout.planSpace))
                .onChange(of: selection) {
                    if menuTarget != selection { menuTarget = nil }
                }
        }
    }

    /// 고른 스탬프의 ✕·↻ 손잡이, 또는 꾹 눌러 띄운 복제·삭제 메뉴
    @ViewBuilder
    private func stampControls(screen: PlanScreen) -> some View {
        let plan = dragPreview ?? planData
        if let selection, let point = stampPoint(of: selection, in: plan) {
            let center = screen.point(point)
            let halfSize = screen.length(Plan2DView.stampSize) / 2 + Plan2DView.selectionPadding
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
                    yaw: markerYaw(of: selection, in: plan),
                    coordinateSpace: Layout.planSpace,
                    onDelete: { handleEdit(.delete(selection)) },
                    onRotate: { yaw in rotatePreview(selection, yaw: yaw) },
                    onRotateEnded: commitPreview
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
                handleTap(screen.tap(at: value.location, in: planData))
            }
    }

    /// 이미 놓인 스탬프를 누르면 도구와 상관없이 그것을 고른다.
    /// 빈 곳은 스탬프 도구를 골랐으면 맞는 자리(발화지점·피해자는 바닥, 전기는 벽)에 놓고, 도구가 없으면 고른 것을 푼다.
    /// 도구는 놓은 뒤에도 켜져 있고, 방금 놓은 스탬프를 고른 상태로 둔다 (3D 수정 화면과 같다)
    private func handleTap(_ tap: PlanTap) {
        switch (selectedTool, tap) {
        case (_, .element(let element)):
            selection = element
        case (nil, _):
            selection = nil
        case (let tool?, _):
            selection = planData.place(tool, at: tap) ?? selection
        }
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
    /// 사람·발화지점의 방향 (도). 방향이 없는 것(콘센트)은 nil
    private func markerYaw(of selection: PlanSelection, in plan: PlanData) -> Double? {
        guard case .marker(let id) = selection else { return nil }
        return plan.markers.first { $0.id == id }?.yaw
    }

    /// 돌리는 동안은 미리 보기 도면만 돌린다
    private func rotatePreview(_ selection: PlanSelection, yaw: Double) {
        guard case .marker(let id) = selection else { return }
        var preview = dragPreview ?? planData
        _ = preview.apply(.rotate(markerId: id, yaw: yaw), selection: selection)
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
                guard let screen, let pressLocation,
                      let stamp = screen.stamp(at: pressLocation, in: planData) else { return }
                selection = stamp
                menuTarget = stamp
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

// 2D 도면 수정 화면. 도면을 화면에 맞춰 보여 주고 두 손가락으로 확대·축소하고 옮긴다. 스탬프·공간 이름·벽 수정은 이어서 들어온다

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
            Plan2DView(planData: planData, screen: screen)
        }
    }

    private var toolBar: some View {
        EditToolBar(selectedTool: $selectedTool)
            .padding()
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

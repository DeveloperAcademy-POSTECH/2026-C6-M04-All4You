// 사건 작업 메인의 도면 탭. 도면(보기 전용), 필터 메뉴, 2D/3D 전환으로 구성된다

import SwiftUI

/// 도면을 보고 사진 표시 방식과 2D/3D를 고르는 탭
struct FloorPlanTabView: View {
    @Binding var photoFilter: PhotoFilter
    @Binding var dimension: Dimension
    /// 보여 줄 도면. 없으면 회색 자리를 보여 준다
    var planData: PlanData? = nil

    /// 2D 도면이 화면에 놓인 배율과 자리. 화면 크기를 알게 되면 만든다
    @State private var screen: PlanScreen?
    /// 오므리는 동안 직전까지 적용한 배율. 바뀐 만큼만 screen에 곱한다
    @State private var lastMagnification = 1.0

    /// 도면을 평면으로 볼지 입체로 볼지
    typealias Dimension = PlanDimension

    var body: some View {
        floorPlanArea
            .overlay(alignment: .topLeading) {
                PhotoFilterMenu(filter: $photoFilter)
                    .padding()
            }
            .overlay(alignment: .bottom) {
                DimensionPicker(selection: $dimension)
                    .padding()
            }
    }
}

// 서브 뷰
extension FloorPlanTabView {
    /// 2D는 화면에 맞춰 그리고 두 손가락으로 확대·이동하며, 3D는 돌리고 확대해 볼 수만 있다. 둘 다 고치기는 받지 않는다
    // TODO: 사진 필터에 따라 도면 위 사진 표시 바꾸기
    @ViewBuilder
    private var floorPlanArea: some View {
        if let planData {
            switch dimension {
            case .twoD:
                GeometryReader { proxy in
                    if let screen {
                        Plan2DView(planData: planData, screen: screen)
                    }
                    Color.clear
                        .onAppear { fitPlan(planData, in: proxy.size) }
                        .onChange(of: proxy.size) { _, size in fitPlan(planData, in: size) }
                }
                // 처음 맞출 때 도면이 위 필터 메뉴·아래 2D/3D 막대와 겹치지 않게 한다
                .padding(.vertical, Layout.overlayInset)
                .background(.white)
                // 옮기거나 확대한 도면이 상단 바 위로 넘쳐 보이지 않게 한다
                .clipped()
                .contentShape(.rect)
                .gesture(zoomGesture)
                .gesture(TwoFingerPanGesture(onChanged: panPlan))
            case .threeD:
                // 고른 것이 없고 누르기·편집 알림을 버리므로 카메라 조작만 남는다
                FloorPlan3DView(planData: planData, selection: nil, onTap: { _ in }, onEdit: { _ in })
            }
        } else {
            Text(Copy.placeholder)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.quaternary)
        }
    }
}

// 2D 확대·이동
extension FloorPlanTabView {
    /// 도면을 화면 크기에 맞춰 다시 놓는다
    private func fitPlan(_ planData: PlanData, in size: CGSize) {
        screen = PlanScreen(plan: planData, in: size, fill: Layout.planFill)
    }

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
extension FloorPlanTabView {
    private enum Layout {
        /// 화면에서 도면이 차지하는 몫
        static let planFill = 0.85
        /// 위 필터 메뉴·아래 2D/3D 막대와 도면이 겹치지 않게 비우는 위·아래 높이 (pt)
        static let overlayInset: CGFloat = 80
    }
}

// 문구
extension FloorPlanTabView {
    private enum Copy {
        static let placeholder = "도면 자리"
    }
}

#Preview {
    @Previewable @State var photoFilter = PhotoFilter()
    @Previewable @State var dimension: FloorPlanTabView.Dimension = .twoD

    FloorPlanTabView(photoFilter: $photoFilter, dimension: $dimension, planData: DummyFloorPlan.planData)
}

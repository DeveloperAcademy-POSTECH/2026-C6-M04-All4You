// 도면 수정 화면. 상단 바 가운데의 2D·3D 전환 막대로 2D 수정과 3D 수정을 오가며 고친다.
// 두 화면을 계속 띄워 두고 겹쳐서 부드럽게 바꾼다(확대·카메라 위치도 그대로 남는다). 완료(✓)는 변환 화면을 거쳐 메인으로 간다

import SwiftUI

/// 2D 수정과 3D 수정을 감싸는 화면. 도면·되돌리기 기록·켜 둔 스탬프 도구는 두 화면이 함께 쓴다
struct FloorPlanEditView: View {
    /// 2D·3D 수정 화면과 메인이 함께 보고 고치는 도면
    @Binding var planData: PlanData
    /// 2D·3D가 함께 쓰는 되돌리기·다시 하기 기록
    @Binding var history: PlanHistory
    let onBack: () -> Void
    let onDone: () -> Void
    /// 2D 수정 화면이 처음 한 번 보여 줄 안내 (예: 스케치 스탬프를 옮기지 못했다는 알림)
    var launchNotice: String? = nil

    @State private var dimension = PlanDimension.twoD
    /// 켜 둔 스탬프 도구. 전환해도 이어지되, 3D에 없는 도구는 3D로 갈 때 끈다
    @State private var selectedTool: EditTool?
    /// 발화지점·전기 도구에서 고른 종류(발화원인·전기 종류). 도구가 바뀌어 그 도구의 종류가 아니게 되면(끄거나, 한 번 놓아서 꺼지면) 다시 고르게 비운다
    @State private var stampOption: StampOption?
    /// 올라가면 2D·3D 수정 화면이 고른 것·메뉴·미리 보기를 비운다. 되돌리기·다시 하기와 전환 때 올린다
    @State private var resetToken = 0
    /// 3D 화면을 만들어 뒀는지. 화면에 들어오자마자 만들면 느려서 잠시 뒤에 만들고, 3D를 먼저 누르면 바로 만든다
    @State private var isThreeDReady = false
    /// 치수·면적 글자 설정. 2D·3D 수정 화면이 함께 쓴다
    @State private var dimensions = DimensionDisplay()
    /// 스탬프 기본 크기. 화면 크기를 처음 알았을 때 정하고 바꾸지 않는다
    @State private var stampDefaults: StampDefaults?
    /// 완료(✓)를 눌러 "이대로 도면을 완성할지" 묻는 알림을 띄우는지
    @State private var isCompleteAlertShown = false

    var body: some View {
        ZStack {
            FloorPlanEdit2DView(planData: $planData, history: $history, selectedTool: $selectedTool, stampOption: $stampOption, stampDefaults: stampDefaults, resetToken: resetToken, dimensions: $dimensions, launchNotice: launchNotice)
                .modifier(DimensionLayer(isShown: dimension == .twoD))
            if isThreeDReady {
                FloorPlanEdit3DView(planData: $planData, history: $history, selectedTool: $selectedTool, stampOption: $stampOption, stampDefaults: stampDefaults, resetToken: resetToken, dimensions: $dimensions)
                    .modifier(DimensionLayer(isShown: dimension == .threeD))
            }
        }
        .animation(.easeInOut(duration: Layout.fadeDuration), value: dimension)
        .onChange(of: selectedTool) {
            // 고른 종류가 지금 도구의 것이 아니면(도구를 바꾸거나 껐거나, 놓아서 도구가 꺼짐) 비워 다시 고르게 한다
            if let stampOption, selectedTool?.stampOptions.contains(stampOption) != true { self.stampOption = nil }
        }
        // 위 바 아래 도면 영역 크기로 스탬프 기본 크기를 정한다. 2D 수정 화면이 처음 도면을 맞추는 것과 같은 식이다
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
            // 화면이 막 생길 때는 높이가 0에 가까운 값이 먼저 오므로, 위·아래 막대를 뺀 높이가 충분해진 뒤의 값만 쓴다
            guard stampDefaults == nil, size.width > Layout.minimumFitSide, size.height > Layout.fitBarInset * 2 + Layout.minimumFitSide else { return }
            let inner = CGSize(width: size.width, height: max(size.height - Layout.fitBarInset * 2, 1))
            stampDefaults = StampDefaults(pointsPerMeter: PlanScreen(plan: planData, in: inner, fill: Layout.planFill).fitScale)
        }
        .task {
            try? await Task.sleep(for: Layout.threeDWarmUp)
            isThreeDReady = true
        }
        .onChange(of: dimension) {
            if dimension == .threeD { isThreeDReady = true }
            // 고른 스탬프·벽·이름 선택은 화면마다 따로라 전환하면 푼다. 켜 둔 도구는 3D에 없는 것(공간라벨·가구라벨)만 끈다
            resetToken += 1
            if let selectedTool, dimension == .threeD, FloorPlanEdit3DView.hiddenTools.contains(selectedTool) {
                self.selectedTool = nil
            }
        }
        .bothSidesToolbar(
            customLayout: true,
            barTitle: Copy.title,
            titleFont: .largeTitle.bold(),
            centerAccessory: AnyView(DimensionPicker(selection: $dimension)),
            trailingAccessory: AnyView(undoRedo),
            onBack: onBack,
            // ✓는 도면을 확정하는 버튼인데 방금 고친 것을 저장하는 버튼으로 오해하기 쉬워서, 한 번 묻는다
            onDone: { isCompleteAlertShown = true }
        )
        .alert(Copy.completeTitle, isPresented: $isCompleteAlertShown) {
            Button(Copy.cancel, role: .cancel) {}
            Button(Copy.complete, action: onDone)
        }
    }

    /// 되돌리면 고른 것이 사라졌을 수 있어 두 화면의 고르기를 푼다
    private var undoRedo: some View {
        UndoRedoCapsule(history: $history, planData: $planData) {
            resetToken += 1
        }
    }
}

// 레이아웃 값
extension FloorPlanEditView {
    private enum Layout {
        /// 2D·3D가 바뀔 때 서로 겹쳐 바뀌는 시간 (초)
        static let fadeDuration = 0.3
        /// 3D 화면을 미리 만들어 두기까지 기다리는 시간
        static let threeDWarmUp = Duration.seconds(1)
        /// 2D 수정 화면이 처음 도면을 맞출 때 도구 막대를 피해 위·아래로 남기는 높이 (pt). FloorPlanEdit2DView의 toolBarInset과 같은 값
        static let fitBarInset: CGFloat = 90
        /// 맞출 때 도면이 영역에서 차지하는 몫. FloorPlanEdit2DView의 planFill과 같은 값
        static let planFill = 0.85
        /// 이보다 작은 크기는 아직 자리를 잡는 중인 값으로 보고 무시한다 (pt)
        static let minimumFitSide: CGFloat = 200
    }
}

// 문구
extension FloorPlanEditView {
    private enum Copy {
        static let title = "도면 수정"
        // TEMP: Figma에 알림 버튼 문구가 없어 임의로 작성 — 디자인 확인 필요
        static let completeTitle = "이대로 도면을 완성하시겠습니까?"
        static let complete = "완성"
        static let cancel = "취소"
    }
}

#Preview {
    @Previewable @State var planData = DummyFloorPlan.planData
    @Previewable @State var history = PlanHistory()

    NavigationStack {
        FloorPlanEditView(planData: $planData, history: $history, onBack: {}, onDone: {})
    }
}

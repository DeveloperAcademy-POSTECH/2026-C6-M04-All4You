// 도면 수정부터 사건 작업 메인까지의 화면을 확인하기 위해 임시로 이어 둔 화면 흐름
// TEMP: 다른 팀원 화면과의 이동 방식이 아직 정해지지 않아 이 파트 확인용으로만 만듦 — 팀 논의 후 바뀌거나 없어질 수 있음

import SwiftData
import SwiftUI

/// 화면 더미에 쌓을 수 있는 화면 목록
enum CaseRoute: Hashable {
    case edit2D
    case conversionLoading
    case edit3D
}

/// 2D 수정에서 시작해 화면 더미(path)를 쌓고 빼며 이동한다.
/// 메인은 더미에 쌓지 않고 더미 대신 바꿔 끼워 보여 준다. 더미 안에 있으면 메인의 탭 막대가 상단 바 아래 줄로 내려가기 때문이다.
/// 전체 화면으로 덮어 띄우면 저장된 사건을 열 때 2D 수정이 먼저 보였다가 메인이 올라와서, 바꿔 끼우는 방식으로 메인이 바로 보이게 한다
struct CaseFlowView: View {
    /// 지금 작업 중인 사건. 도면은 이 사건의 평면도에 저장한다
    let fireCase: FireCase
    /// 사건 화면을 닫고 목록으로 돌아간다
    let onClose: () -> Void

    @State private var path: [CaseRoute] = []
    @State private var isCaseMainShown: Bool
    /// 2D·3D 수정 화면이 함께 보고 고치는 도면. 바뀔 때마다 사건의 평면도에 저장한다
    @State private var planData: PlanData
    /// 메인에서 찍거나 불러온 사진. 사건의 사진 모델에 저장하고, 메인을 닫았다 열어도 같은 것을 본다
    @State private var photoStore: PhotoStore
    /// 2D·3D 수정 화면이 함께 쓰는 되돌리기·다시 하기 기록
    @State private var history = PlanHistory()
    /// 도면 저장에 실패했는지. 참이면 알림을 띄운다
    @State private var isSaveFailed = false

    /// 메인에서 처음 보여 줄 탭
    private let startTab: CaseStartTab

    init(fireCase: FireCase, startsAtMain: Bool, startTab: CaseStartTab = .floorPlan, onClose: @escaping () -> Void) {
        self.startTab = startTab
        self.fireCase = fireCase
        self.onClose = onClose
        // 저장된 도면을 열면 메인부터, 막 변환한 도면이면 2D 수정부터 보여 준다
        _isCaseMainShown = State(initialValue: startsAtMain)
        // 평면도가 있는 사건만 열린다(없으면 목록이 도면 방식 선택을 띄움). 저장된 JSON을 못 읽으면 빈 도면
        _planData = State(initialValue: fireCase.floorPlan?.loadPlanData() ?? .empty)
        _photoStore = State(initialValue: PhotoStore(fireCase: fireCase))
    }

    var body: some View {
        Group {
            if isCaseMainShown {
                CaseMainView(fireCase: fireCase, planData: planData, photoStore: photoStore, startTab: startTab, onBack: onClose, onEdit: showEdit2D)
            } else {
                NavigationStack(path: $path) {
                    edit2DScreen
                        .navigationDestination(for: CaseRoute.self) { route in
                            destination(for: route)
                        }
                }
            }
        }
        .onChange(of: planData) { old, new in
            history.record(from: old, to: new)
            storeFloorPlan(new)
        }
        .alert(Copy.saveFailedTitle, isPresented: $isSaveFailed) {
            Button(Copy.confirm, role: .cancel) {}
        } message: {
            Text(Copy.saveFailedMessage)
        }
    }
}

// 서브 뷰
extension CaseFlowView {
    /// 처음 시작할 때와 메인의 "수정"으로 들어올 때 함께 쓰는 2D 수정 화면
    private var edit2DScreen: some View {
        FloorPlanEdit2DView(planData: $planData, history: $history, onBack: goBack, onDone: showConversionLoading)
    }

    /// 화면 목록의 값에 맞는 화면을 만든다
    @ViewBuilder
    private func destination(for route: CaseRoute) -> some View {
        switch route {
        case .edit2D:
            edit2DScreen
        case .conversionLoading:
            ConversionLoadingView(planData: planData, onFinished: replaceLoadingWithEdit3D)
        case .edit3D:
            FloorPlanEdit3DView(planData: $planData, history: $history, onBack: goBack, onDone: showCaseMain)
        }
    }
}

// 저장
extension CaseFlowView {
    /// 고친 도면을 사건의 평면도에 덮어쓴다
    private func storeFloorPlan(_ plan: PlanData) {
        do {
            try fireCase.floorPlan?.storePlanData(plan)
        } catch {
            isSaveFailed = true
        }
    }
}

// 화면 이동
extension CaseFlowView {
    /// 한 화면 뒤로 돌아간다. 맨 처음 2D 수정에서는 목록으로 돌아간다
    private func goBack() {
        if path.isEmpty {
            onClose()
            return
        }
        path.removeLast()
    }

    private func showConversionLoading() {
        path.append(.conversionLoading)
    }

    /// 로딩을 3D 수정으로 바꿔 끼운다. 3D에서 뒤로 가면 로딩을 건너뛰고 2D로 돌아가게 하기 위함이다
    private func replaceLoadingWithEdit3D() {
        path.removeLast()
        path.append(.edit3D)
    }

    /// 메인을 띄우고, 메인 밑의 더미는 처음 3D 수정까지만 남긴다.
    /// "수정"으로 다시 고치고 돌아올 때마다 2D·3D 수정이 계속 쌓이는 것을 막는다
    private func showCaseMain() {
        if let firstEdit3DIndex = path.firstIndex(of: .edit3D) {
            path.removeSubrange((firstEdit3DIndex + 1)...)
        }
        isCaseMainShown = true
    }

    /// 메인을 닫고 2D 수정을 더미에 쌓는다
    private func showEdit2D() {
        isCaseMainShown = false
        path.append(.edit2D)
    }
}

// 문구
extension CaseFlowView {
    private enum Copy {
        // TEMP: Figma에 도면 저장 실패 화면이 없어 임의로 작성 — 디자인 확인 필요
        static let saveFailedTitle = "도면을 저장하지 못했어요"
        static let saveFailedMessage = "방금 고친 내용이 저장되지 않았을 수 있어요. 다시 고쳐 보거나 앱을 다시 열어 주세요."
        static let confirm = "확인"
    }
}

#Preview {
    CaseFlowView(fireCase: FireCase(address: "서울시 강남구 청암로 77", occurredAt: .now), startsAtMain: false, onClose: {})
        .modelContainer(for: FireCase.self, inMemory: true)
}

// 도면 수정부터 사건 작업 메인까지의 화면을 확인하기 위해 임시로 이어 둔 화면 흐름
// TEMP: 다른 팀원 화면과의 이동 방식이 아직 정해지지 않아 이 파트 확인용으로만 만듦 — 팀 논의 후 바뀌거나 없어질 수 있음

import SwiftUI

/// 화면 더미에 쌓을 수 있는 화면 목록
enum CaseRoute: Hashable {
    case edit2D
    case conversionLoading
    case edit3D
}

/// 2D 수정에서 시작해 화면 더미(path)를 쌓고 빼며 이동한다.
/// 메인은 더미에 쌓지 않고 전체 화면으로 덮어 띄운다. 더미 안에 있으면 메인의 탭 막대가 상단 바 아래 줄로 내려가기 때문이다
struct CaseFlowView: View {
    @State private var path: [CaseRoute] = []
    @State private var isCaseMainShown = false
    /// 2D·3D 수정 화면이 함께 보고 고치는 도면
    // TEMP: 도면을 만들고 저장하는 흐름(SwiftData)이 연결되기 전이라 더미 도면을 여기서 들고 있음 — 앱을 끄면 고친 것이 사라짐
    @State private var planData = DummyFloorPlan.planData
    /// 2D·3D 수정 화면이 함께 쓰는 되돌리기·다시 하기 기록
    @State private var history = PlanHistory()

    var body: some View {
        NavigationStack(path: $path) {
            edit2DScreen
                .navigationDestination(for: CaseRoute.self) { route in
                    destination(for: route)
                }
        }
        .onChange(of: planData) { old, new in
            history.record(from: old, to: new)
        }
        .fullScreenCover(isPresented: $isCaseMainShown) {
            CaseMainView(onBack: closeCaseMain, onEdit: showEdit2D, planData: planData)
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

// 화면 이동
extension CaseFlowView {
    /// 한 화면 뒤로 돌아간다
    private func goBack() {
        // TODO: 앞 단계(평면도 생성) 화면이 생기면 시작 화면의 뒤로가기를 그쪽으로 연결
        if path.isEmpty { return }
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

    /// 메인을 닫는다. 메인 밑에 있던 3D 수정으로 돌아간다
    private func closeCaseMain() {
        isCaseMainShown = false
    }

    /// 메인을 닫고 2D 수정을 더미에 쌓는다
    private func showEdit2D() {
        isCaseMainShown = false
        path.append(.edit2D)
    }
}

#Preview {
    CaseFlowView()
}

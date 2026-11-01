// 도면 수정부터 사진 업로드까지의 화면을 확인하기 위해 임시로 이어 둔 화면 흐름
// TEMP: 다른 팀원 화면과의 이동 방식이 아직 정해지지 않아 이 파트 확인용으로만 만듦 — 팀 논의 후 바뀌거나 없어질 수 있음

import SwiftUI

/// 화면 더미에 쌓을 수 있는 화면 목록
enum CaseRoute: Hashable {
    case edit2D
    case conversionLoading
    case edit3D
    case caseMain
    case photoUpload
}

/// 2D 수정에서 시작해 화면 더미(path)를 쌓고 빼며 이동한다
struct CaseFlowView: View {
    @State private var path: [CaseRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            edit2DScreen
                .navigationDestination(for: CaseRoute.self) { route in
                    destination(for: route)
                }
        }
    }
}

// 서브 뷰
extension CaseFlowView {
    /// 처음 시작할 때와 메인의 "수정"으로 들어올 때 함께 쓰는 2D 수정 화면
    private var edit2DScreen: some View {
        FloorPlanEdit2DView(onBack: goBack, onDone: showConversionLoading)
    }

    /// 화면 목록의 값에 맞는 화면을 만든다
    @ViewBuilder
    private func destination(for route: CaseRoute) -> some View {
        switch route {
        case .edit2D:
            edit2DScreen
        case .conversionLoading:
            ConversionLoadingView(onFinished: replaceLoadingWithEdit3D)
        case .edit3D:
            FloorPlanEdit3DView(onBack: goBack, onDone: showCaseMain)
        case .caseMain:
            CaseMainView(onBack: goBack, onEdit: showEdit2D, onAddPhoto: showPhotoUpload)
        case .photoUpload:
            PhotoUploadView(onBack: goBack)
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

    /// 메인이 이미 더미에 있으면 그 위 화면을 걷어 내고, 없으면 새로 쌓는다.
    /// "수정"으로 다시 고치고 돌아올 때마다 메인이 계속 쌓이는 것을 막는다
    private func showCaseMain() {
        if let mainIndex = path.firstIndex(of: .caseMain) {
            path.removeSubrange((mainIndex + 1)...)
        } else {
            path.append(.caseMain)
        }
    }

    private func showEdit2D() {
        path.append(.edit2D)
    }

    private func showPhotoUpload() {
        path.append(.photoUpload)
    }
}

#Preview {
    CaseFlowView()
}

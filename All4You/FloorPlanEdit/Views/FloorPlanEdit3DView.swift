// 3D 도면 수정 화면. 도면을 3D로 보여 주고, 스탬프를 놓고 옮기고 돌리고 복제·삭제하고, 창문을 달고 크기를 바꾸고 지운다

import SwiftUI

/// 3D 도면을 고치는 화면
struct FloorPlanEdit3DView: View {
    /// 2D·3D 수정 화면과 메인이 함께 보는 도면
    @Binding var planData: PlanData
    /// 2D 수정 화면과 함께 쓰는 되돌리기·다시 하기 기록
    @Binding var history: PlanHistory
    /// 위 도구 막대에서 켠 스탬프 도구. 2D·3D 전환 화면이 함께 들고 있어서 전환해도 이어진다
    @Binding var selectedTool: EditTool?
    /// 위 도구 막대의 옵션 줄에서 고른 종류. 발화지점·전기는 종류를 골라야 놓을 수 있다
    @Binding var stampOption: StampOption?
    /// 스탬프를 놓을 때 쓰는 Figma 기본 크기. nil이면 addMarker·addOpening의 기본 크기를 쓴다
    var stampDefaults: StampDefaults? = nil
    /// 값이 바뀔 때마다 고른 것을 푼다 (되돌리기·다시 하기나 2D·3D 전환 때 부모가 올린다)
    var resetToken = 0
    /// 치수·면적 글자 설정. 2D·3D 전환 화면이 함께 들고 있어서 전환해도 이어진다
    @Binding var dimensions: DimensionDisplay

    /// 3D에서 눌러 고른 스탬프·창문
    @State private var selection: PlanSelection?
    /// 위쪽에 잠깐 보여 주는 안내
    @State private var notice: String?
    /// 안내를 일정 시간 뒤 내리는 작업. 새 안내가 뜨면 이전 것을 취소한다
    @State private var noticeDismissTask: Task<Void, Never>?

    /// 3D에서 가구는 만들 수 없고(고른 가구만 옮기고 돌리고 크기를 바꿈) 공간 이름은 라벨로만 보여 주므로 두 도구를 숨긴다
    static let hiddenTools: Set<EditTool> = [.roomName, .furniture]

    var body: some View {
        FloorPlan3DView(planData: planData, selection: selection, onTap: handleTap, onEdit: handleEdit, showsResetButton: true, showsCompass: true, isStampToolActive: selectedTool != nil, tapsThroughFurniture: tapsThroughFurniture, tapsFurnitureTopAsFloor: placesOnFurniture, onRenameRoom: renameRoom, onRenameFurniture: renameFurniture, resetToken: resetToken, dimensions: $dimensions, scalesLabels: true)
            .overlay(alignment: .topLeading) {
                toolBar
            }
            .overlay(alignment: .top) {
                noticeCapsule
            }
            .onChange(of: resetToken) { selection = nil }
    }
}

// 안내
extension FloorPlanEdit3DView {
    /// 도구 막대와 옵션 줄 아래에 잠깐 보여 주는 안내. 2D 수정 화면의 안내와 같은 모양
    @ViewBuilder
    private var noticeCapsule: some View {
        if let notice {
            Text(notice)
                .font(AppTypography.subheadline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Layout.noticeHorizontalPadding)
                .padding(.vertical, Layout.noticeVerticalPadding)
                .frame(maxWidth: Layout.noticeMaxWidth)
                .background(Color.gray900, in: .rect(cornerRadius: Layout.noticeCornerRadius))
                .padding(.top, Layout.noticeTopPadding)
        }
    }

    private func showNotice(_ text: String) {
        notice = text
        noticeDismissTask?.cancel()
        noticeDismissTask = Task {
            try? await Task.sleep(for: Layout.noticeDuration)
            if !Task.isCancelled, notice == text { notice = nil }
        }
    }
}

// 레이아웃 값·문구
extension FloorPlanEdit3DView {
    private enum Layout {
        /// 도구 막대(54)와 옵션 줄(36) 아래 (2D 수정 화면과 같은 자리)
        static let noticeTopPadding: CGFloat = 16 + 54 + 44
        static let noticeMaxWidth: CGFloat = 560
        static let noticeCornerRadius: CGFloat = 22
        static let noticeHorizontalPadding: CGFloat = 20
        static let noticeVerticalPadding: CGFloat = 8
        static let noticeDuration = Duration.seconds(2)
    }

    private enum Copy {
        // TEMP: Figma에 안내 문구가 없어 임의로 작성 — 디자인 확인 필요
        static let pickKindFirst = "종류를 먼저 골라 주세요"
    }
}

// 스탬프가 가구와 겹칠 때
// 사람·발화지점은 가구 위에 올라오도록 가구 윗면을 눌러 놓고, 전기·창문·문은 가구 밑·뒤에 있을 수 있어 가구를 지나쳐 그 뒤 바닥·벽에 놓는다
extension FloorPlanEdit3DView {
    private var placesOnFurniture: Bool {
        selectedTool == .person || selectedTool == .ignitionPoint
    }

    private var tapsThroughFurniture: Bool {
        selectedTool != nil && !placesOnFurniture
    }
}

// 서브 뷰
extension FloorPlanEdit3DView {
    private var toolBar: some View {
        EditToolBar(selectedTool: $selectedTool, hiddenTools: Self.hiddenTools, stampOption: $stampOption)
            .padding()
    }
}

// 누른 자리 처리
extension FloorPlanEdit3DView {
    /// 이미 놓인 스탬프·창문을 누르면 도구와 상관없이 그것을 고른다.
    /// 빈 곳은 스탬프 도구를 골랐으면 맞는 자리(발화지점·피해자는 바닥, 전기는 벽)에 놓고, 도구가 없으면 고른 것을 푼다.
    /// 도구는 한 번 놓으면 꺼진다.
    /// 방금 놓은 스탬프를 고른 상태로 둔다
    private func handleTap(_ tap: PlanTap?) {
        switch (selectedTool, tap) {
        case (_, .element(let element)?):
            selection = element
        case (nil, _):
            selection = nil
        case (let tool?, let tap?):
            // 발화지점·전기는 종류를 먼저 골라야 놓는다
            if !tool.stampOptions.isEmpty, stampOption == nil {
                showNotice(Copy.pickKindFirst)
                return
            }
            if let placed = planData.place(tool, at: tap, defaults: stampDefaults, option: stampOption) {
                selection = placed
                // 한 번 놓으면 도구가 꺼진다. 한 번에 여러 개 놓이지 않게 한다
                selectedTool = nil
            }
        case (_?, nil):
            break
        }
    }

    /// 3D에서 캡슐을 눌러 고친 공간·가구 이름을 도면에 넣는다
    private func renameRoom(id: String, name: String) {
        planData.renameRoom(id: id, to: name)
    }

    private func renameFurniture(id: String, name: String) {
        planData.renameFurniture(id: id, to: name)
    }

    /// 옮기거나 돌리거나 복제·삭제한 스탬프를 도면에 반영한다. 복제하면 새 것을, 지우면 아무것도 고르지 않은 상태로 둔다
    private func handleEdit(_ edit: PlanEdit) {
        selection = planData.apply(edit, selection: selection)
    }
}

#Preview {
    @Previewable @State var planData = DummyFloorPlan.planData
    @Previewable @State var history = PlanHistory()
    @Previewable @State var selectedTool: EditTool?
    @Previewable @State var stampOption: StampOption?
    @Previewable @State var dimensions = DimensionDisplay()
    NavigationStack {
        FloorPlanEdit3DView(planData: $planData, history: $history, selectedTool: $selectedTool, stampOption: $stampOption, dimensions: $dimensions)
    }
}

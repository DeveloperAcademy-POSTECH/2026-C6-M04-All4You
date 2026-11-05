// 사건 화면 왼쪽 사이드바. 도면(2D·3D)·앨범·메모 구역을 접고 펴며 볼 줄을 고른다.
// 맨 윗줄에 편집과 닫기 버튼이 있다. 열고 닫기는 CaseTabView가 정한다

import SwiftUI

/// 도면·앨범·메모 구역과 그 안의 줄. 고른 줄은 회색 알약 바탕으로 보인다
struct CaseSidebar: View {
    @Binding var selection: CaseTabSelection
    let albumRows: [CaseSidebarRow]
    let memoRows: [CaseSidebarRow]
    let onClose: () -> Void
    // 확인 창에서 삭제를 누르면 그 줄(.album·.memo)의 사진·메모를 비운다. 줄 자체는 남는다
    let onClearRow: (CaseTabSelection) -> Void

    // 구역마다 펼쳐져 있는지
    @State private var isFloorPlanExpanded = true
    @State private var isAlbumExpanded = true
    @State private var isMemoExpanded = true
    // 편집 중이면 앨범·메모 줄에 빨간 빼기 버튼이 보이고, 도면 줄은 흐려진다
    @State private var isEditing = false
    // 빼기 버튼 → "삭제"를 누른 줄. 값이 있으면 확인 창이 뜬다
    @State private var clearRequest: ClearRequest?

    var body: some View {
        // 사이드바만의 상단 바(편집·닫기)를 두려고 NavigationStack으로 감싼다.
        // 탭 안이 아니라 탭 옆에 놓이므로 NavigationStack이 겹치지 않는다
        NavigationStack {
            List(selection: listSelection) {
                floorPlanSection
                albumSection
                memoSection
            }
            .listStyle(.sidebar)
            // 목록의 편집 모드를 켜야 지울 수 있는 줄(onDelete)에 빨간 빼기 버튼이 나온다
            .environment(\.editMode, .constant(isEditing ? .active : .inactive))
            .toolbar {
                sidebarToolbar
            }
            .alert(
                clearRequest?.title ?? "",
                isPresented: isClearAlertShown,
                presenting: clearRequest
            ) { request in
                Button(CaseTabCopy.delete, role: .destructive) {
                    onClearRow(request.value)
                    isEditing = false
                }
                Button(CaseTabCopy.cancel, role: .cancel) {}
            } message: { request in
                Text(request.message)
            }
        }
        .frame(width: Layout.width)
    }
}

// 서브 뷰
extension CaseSidebar {
    private var floorPlanSection: some View {
        Section(CaseTabCopy.floorPlan, isExpanded: $isFloorPlanExpanded) {
            Group {
                row(CaseTabCopy.twoD, systemImage: "square.on.square", value: .floorPlan2D)
                row(CaseTabCopy.threeD, systemImage: "point.3.connected.trianglepath.dotted", value: .floorPlan3D)
            }
            // 도면은 지울 수 없어서, 편집 중에는 흐리게 한다. 눌리지 않는 것은 listSelection이 막는다
            .deleteDisabled(true)
            .opacity(isEditing ? Layout.disabledOpacity : 1)
        }
    }

    private var albumSection: some View {
        placeSection(CaseTabCopy.album, rows: albumRows, isExpanded: $isAlbumExpanded) { name in
            .album(name)
        }
    }

    private var memoSection: some View {
        placeSection(CaseTabCopy.memo, rows: memoRows, isExpanded: $isMemoExpanded) { name in
            .memo(name)
        }
    }

    /// 앨범·메모 구역. 두 구역은 모양이 같고, 줄을 골랐을 때의 값(앨범 줄인지 메모 줄인지)만 다르다
    private func placeSection(
        _ title: String,
        rows: [CaseSidebarRow],
        isExpanded: Binding<Bool>,
        value: @escaping (String) -> CaseTabSelection
    ) -> some View {
        Section(title, isExpanded: isExpanded) {
            ForEach(rows, id: \.name) { placeRow in
                row(placeRow.name, systemImage: placeRow.systemImage, value: value(placeRow.name), count: placeRow.count)
                    // 이미 비어 있는 줄은 지울 것이 없어 빼기 버튼을 두지 않는다
                    .deleteDisabled(placeRow.count == 0)
                    // 빼기 버튼을 누르거나 줄을 밀면 나오는 "삭제". 바로 지우지 않고 확인 창을 띄운다.
                    // 애플 기본 삭제(onDelete, role: .destructive)는 누르는 순간 줄을 목록에서 빼 버려서,
                    // 줄이 남는 이 화면에서는 줄이 사라졌다 다시 나타난다. 그래서 역할 없는 버튼에 빨간색만 입힌다
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if placeRow.count > 0 {
                            Button(CaseTabCopy.delete, systemImage: "trash") {
                                clearRequest = ClearRequest(value: value(placeRow.name), name: placeRow.name, count: placeRow.count)
                            }
                            // 색 자산에 빨강이 없어, ⊖와 같은 애플 시스템 빨강을 쓴다 (2026-11-05 결정)
                            .tint(.red)
                        }
                    }
            }
            // 편집 중 빼기 버튼을 보이게 하려고만 둔다. 눌렀을 때 할 일은 위 swipeActions의 "삭제"가 한다
            .onDelete { _ in }
        }
    }

    /// 맨 윗줄: 왼쪽 편집(편집 중에는 체크 버튼), 오른쪽 닫기
    @ToolbarContentBuilder
    private var sidebarToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if isEditing {
                Button(CaseTabCopy.done, systemImage: "checkmark") {
                    isEditing = false
                }
                .buttonStyle(.glassProminent)
            } else {
                Button(CaseTabCopy.edit) {
                    isEditing = true
                }
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button(CaseTabCopy.closeSidebar, systemImage: "sidebar.left", action: onClose)
        }
    }

    /// 사이드바 한 줄. 오른쪽 숫자(count)는 앨범·메모 줄에만 있다.
    /// 탭 옆에 둔 목록은 애플 기본 모양이 줄마다 흰 칸으로 나와서,
    /// 칸 바탕과 구분선을 끄고 고른 줄만 알약 바탕을 직접 그려 애플 사이드바처럼 보이게 한다.
    /// 숫자(badge)를 칸 바탕보다 먼저 붙여야 칸 바탕 설정이 줄 전체에 먹는다
    private func row(_ title: String, systemImage: String, value: CaseTabSelection, count: Int? = nil) -> some View {
        let isSelected = selection == value
        return Label(title, systemImage: systemImage)
            // 알약 왼쪽 끝과 아이콘 사이를 넉넉히 띄운다
            .padding(.leading, Layout.rowLeadingInset)
            // 숫자로 넘기면 0일 때 숨겨져서, 삭제 뒤 0이 보이도록 글자로 넘긴다. 도면 줄(nil)은 숫자가 없다
            .badge(count.map { Text($0, format: .number) })
            // 고른 줄도 글자색은 다른 줄과 같다. 고른 줄은 알약 바탕으로만 구분한다
            .foregroundStyle(.primary)
            .listRowSeparator(.hidden)
            .listRowBackground(selectedBackground(isSelected))
            .tag(value)
    }

    @ViewBuilder
    private func selectedBackground(_ isSelected: Bool) -> some View {
        if isSelected {
            // 목록 줄 칸 폭을 그대로 써서 알약을 넓게 그린다
            RoundedRectangle(cornerRadius: Layout.selectedCornerRadius)
                .fill(.gray200)
        }
    }
}

// 고른 줄
extension CaseSidebar {
    /// 목록은 "고르지 않음"(nil)도 다루지만 사이드바에서는 늘 한 줄이 골라져 있어서, nil은 무시한다.
    /// 편집 중에는 줄을 눌러도 고르지 않는다 (줄에 .disabled를 붙여도 목록의 고르기는 막히지 않는다)
    private var listSelection: Binding<CaseTabSelection?> {
        Binding(
            get: { selection },
            set: { newSelection in
                guard !isEditing, let newSelection else { return }
                selection = newSelection
            }
        )
    }
}

// 삭제 확인 창
extension CaseSidebar {
    /// 확인 창은 clearRequest에 값이 있을 때 뜨고, 닫히면 값을 지운다
    private var isClearAlertShown: Binding<Bool> {
        Binding(
            get: { clearRequest != nil },
            set: { isShown in
                if !isShown { clearRequest = nil }
            }
        )
    }

    /// 비우려는 줄과 확인 창 문구. 앨범 줄이면 사진, 메모 줄이면 메모 문구를 쓴다
    private struct ClearRequest {
        let value: CaseTabSelection
        let name: String
        let count: Int

        private var isMemo: Bool {
            if case .memo = value { return true }
            return false
        }

        var title: String {
            isMemo ? CaseTabCopy.clearMemoTitle(name) : CaseTabCopy.clearAlbumTitle(name)
        }

        var message: String {
            isMemo ? CaseTabCopy.clearMemoMessage(name, count) : CaseTabCopy.clearAlbumMessage(name, count)
        }
    }
}

// 간격
extension CaseSidebar {
    private enum Layout {
        static let width: CGFloat = 320
        static let selectedCornerRadius: CGFloat = 22
        static let rowLeadingInset: CGFloat = 8
        static let disabledOpacity: CGFloat = 0.4
    }
}

#Preview {
    @Previewable @State var selection = CaseTabSelection.floorPlan2D

    CaseSidebar(
        selection: $selection,
        albumRows: [CaseSidebarRow(name: "거실", systemImage: "lamp.floor", count: 89)],
        memoRows: [CaseSidebarRow(name: "거실", systemImage: "lamp.floor", count: 5)],
        onClose: {},
        onClearRow: { _ in }
    )
}

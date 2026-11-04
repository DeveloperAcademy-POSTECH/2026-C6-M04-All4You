// 사건 화면 상단 바 왼쪽의 사건명과 조사 차수 메뉴.
// 뒤로가기·완료(Global/Toolbar.swift), 오른쪽 버튼 묶음(CaseActionToolbar)과 따로 붙여 화면마다 골라 쓴다

import SwiftUI

extension View {
    /// 상단 바 왼쪽에 사건명과 조사 차수 메뉴를 붙인다.
    /// 나중에 붙인 toolbar의 버튼이 앞에 놓이므로, 뒤로가기를 함께 쓰면 backOnlyToolbar를 이것보다 뒤에 붙인다
    func caseTitleToolbar(
        title: String,
        sessionNumber: Int,
        sessionNumbers: [Int],
        onSelectSession: @escaping (Int) -> Void,
        onAddSession: @escaping () -> Void
    ) -> some View {
        toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Text(title)
                    .font(.largeTitle.bold())
                    // 상단 바가 이 칸을 좁게 잡아 제목이 "청…"으로 잘리므로 글자 길이만큼 자리를 차지하게 한다
                    .fixedSize()
            }
            .sharedBackgroundVisibility(.hidden)

            ToolbarItem(placement: .topBarLeading) {
                SessionMenuButton(
                    sessionNumber: sessionNumber,
                    sessionNumbers: sessionNumbers,
                    onSelectSession: onSelectSession,
                    onAddSession: onAddSession
                )
            }
            // figma 디자인과 유사하게 하기 위해 기본 상단바 유리를 숨겼다
            .sharedBackgroundVisibility(.hidden)
        }
    }
}

/// "1차 조사 ⌄" 캡슐 버튼. 누르면 아래로 차수 목록과 "새 조사 만들기"가 든 작은 창이 뜬다
private struct SessionMenuButton: View {
    let sessionNumber: Int
    let sessionNumbers: [Int]
    let onSelectSession: (Int) -> Void
    let onAddSession: () -> Void

    @State private var isOpen = false

    var body: some View {
        Button {
            isOpen = true
        } label: {
            capsuleLabel
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isOpen, arrowEdge: .top) {
            sessionPanel
        }
    }
}

// 서브 뷰
extension SessionMenuButton {
    private var capsuleLabel: some View {
        HStack(spacing: Layout.capsuleLabelSpacing) {
            Text(Copy.sessionTitle(sessionNumber))
                .font(AppTypography.subheadline)
            Image(systemName: "chevron.down")
                .font(AppTypography.label)
        }
        // 상단 바가 이 칸을 좁게 잡아 글자가 사라지므로 글자 길이만큼 자리를 차지하게 한다
        .fixedSize()
        .padding(.horizontal, Layout.capsulePadding)
        .frame(height: Layout.capsuleHeight)
        // 크기는 Figma 캡슐 그대로 두고, 바탕만 다른 상단 바 버튼과 같은 유리 효과로 한다
        .glassEffect(in: .capsule)
    }

    /// 차수 목록, 구분선, "새 조사 만들기" 줄
    private var sessionPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(sessionNumbers, id: \.self) { number in
                sessionRow(number)
            }
            Divider()
                .padding(.vertical, Layout.dividerPadding)
            panelRow(Copy.addSession, action: onAddSession) {
                Image(systemName: "plus")
            }
        }
        .buttonStyle(.plain)
        .font(AppTypography.subheadline)
        .padding(Layout.panelPadding)
        .frame(width: Layout.panelWidth)
        // 좁은 화면에서도 아래에서 올라오는 시트로 바뀌지 않고 작은 창으로 뜨게 한다
        .presentationCompactAdaptation(.popover)
    }

    /// 차수 한 줄. 지금 차수에만 주황 체크가 보인다
    private func sessionRow(_ number: Int) -> some View {
        let isSelected = number == sessionNumber

        return panelRow(Copy.sessionTitle(number), action: { onSelectSession(number) }) {
            // 체크가 없는 줄도 글자가 같은 자리에서 시작하도록 체크 자리는 남기고 투명하게 한다
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.brand500)
                .opacity(isSelected ? 1 : 0)
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// 왼쪽 아이콘과 글자로 된 한 줄. 누르면 창을 닫고 화면이 넘겨준 일을 한다
    private func panelRow(
        _ title: String,
        action: @escaping () -> Void,
        @ViewBuilder icon: () -> some View
    ) -> some View {
        Button {
            isOpen = false
            action()
        } label: {
            HStack(spacing: Layout.rowLabelSpacing) {
                icon()
                    .frame(width: Layout.rowIconWidth)
                Text(title)
                Spacer()
            }
            .padding(.horizontal, Layout.rowPadding)
            .frame(height: Layout.rowHeight)
            .contentShape(.rect)
        }
    }
}

// 크기
extension SessionMenuButton {
    private enum Layout {
        static let capsuleLabelSpacing: CGFloat = 4
        static let capsulePadding: CGFloat = 10
        static let capsuleHeight: CGFloat = 30
        static let panelWidth: CGFloat = 238
        static let panelPadding: CGFloat = 8
        static let rowHeight: CGFloat = 40
        static let rowPadding: CGFloat = 6
        static let rowLabelSpacing: CGFloat = 8
        static let rowIconWidth: CGFloat = 16
        static let dividerPadding: CGFloat = 8
    }
}

// 문구
extension SessionMenuButton {
    private enum Copy {
        static let addSession = "새 조사 만들기"

        /// 차수 숫자를 화면 글자로 바꾼다. 1 → "1차 조사"
        static func sessionTitle(_ sessionNumber: Int) -> String {
            "\(sessionNumber)차 조사"
        }
    }
}

#Preview {
    NavigationStack {
        Text("화면 내용")
            .caseTitleToolbar(
                title: "청암로 77",
                sessionNumber: 1,
                sessionNumbers: [1, 2],
                onSelectSession: { _ in },
                onAddSession: {}
            )
    }
}

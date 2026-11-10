// 사건 화면 가운데의 도면·앨범·메모 탭 막대와 왼쪽 사이드바(CaseSidebar). 각 탭의 내용은 화면이 넘겨준다.
// 상단 바(CaseTitleToolbar, CaseActionToolbar)와 따로 쓸 수 있다

import SwiftUI

/// 사이드바 앨범·메모 구역의 한 줄. 장소 이름과 그 장소의 사진 수 또는 메모 수
struct CaseSidebarRow {
    let name: String
    let systemImage: String
    // 사이드바에서 삭제하면 0이 된다
    var count: Int
}

/// 사이드바에서 고른 줄. 탭 막대의 도면·앨범·메모는 이 줄이 속한 구역이다
enum CaseTabSelection: Hashable {
    case floorPlan2D
    case floorPlan3D
    /// 앨범 탭의 "전체". 사이드바에는 줄이 없고 앨범 아래 장소 막대에만 있다
    case albumOverview
    // TODO: 장소 데이터가 생기면 이름 대신 Room.id로 구분
    case album(String)
    case memo(String)
}

/// 도면·앨범·메모 탭 막대와 사이드바. 탭 막대 맨 왼쪽 버튼으로 사이드바를 열고 닫는다.
/// 사이드바는 탭 옆에 나란히 놓이고, 탭 막대에는 고른 줄이 속한 구역이 켜진다.
/// 탭마다 상단 바(NavigationStack)를 따로 두어야 iPad에서 탭 막대가 상단 바와 같은 줄에 놓인다.
/// 그래서 이 뷰는 화면 더미 안에 넣지 말고, 상단 바 버튼(toolbar)은 각 탭 내용에 붙인다
struct CaseTabView<FloorPlan: View, Album: View, Memo: View>: View {
    @Binding var selection: CaseTabSelection
    let albumRows: [CaseSidebarRow]
    let memoRows: [CaseSidebarRow]
    /// 앨범 탭 위 빨간 숫자 (위치 미지정 사진 수). 0이면 보이지 않는다
    var albumBadge = 0
    // 사이드바에서 삭제를 확인한 줄. 그 장소의 사진·메모를 비우는 일은 화면이 한다
    let onClearRow: (CaseTabSelection) -> Void
    /// 탭 왼쪽 위에 겹쳐 그릴 줄 (뒤로가기·사건명 등). 사이드바를 펴도 그대로 보인다
    var leadingHeader: AnyView? = nil
    @ViewBuilder let floorPlan: FloorPlan
    @ViewBuilder let album: Album
    @ViewBuilder let memo: Memo

    @State private var isSidebarShown = false
    // 탭 막대에서 다른 탭에 갔다 돌아오면 그 탭에서 마지막으로 고른 줄로 돌아가도록 탭마다 기억한다
    @State private var lastSelections: [CaseTabBarItem: CaseTabSelection] = [:]

    var body: some View {
        HStack(spacing: 0) {
            if isSidebarShown {
                sidebar
            }
            tabs
                .overlay(alignment: .topLeading) {
                    if let leadingHeader {
                        // 사이드바를 접었을 때는 가운데 탭 막대를 덮지 않게 탭 막대 왼쪽 끝까지만 쓴다
                        GeometryReader { proxy in
                            leadingHeader
                                .frame(maxWidth: headerMaxWidth(in: proxy.size.width), alignment: .leading)
                                .padding(.leading, CaseTabLayout.headerLeading)
                                .padding(.top, CaseTabLayout.headerTop)
                        }
                    }
                }
        }
    }
}

// 서브 뷰
extension CaseTabView {
    private var sidebar: some View {
        CaseSidebar(
            selection: $selection,
            albumRows: albumRows,
            memoRows: memoRows,
            onClose: toggleSidebar,
            onClearRow: onClearRow
        )
        .overlay(alignment: .trailing) {
            Divider()
        }
        .transition(.move(edge: .leading))
    }

    private var tabs: some View {
        TabView(selection: tabBarSelection) {
            // 탭 막대 맨 왼쪽의 사이드바 버튼. 탭 모양이지만 이 탭으로 넘어가지 않는다 (tabBarSelection 참고)
            Tab(value: CaseTabBarItem.sidebar) {
                EmptyView()
            } label: {
                Label(CaseTabCopy.sidebar, systemImage: "sidebar.left")
                    .labelStyle(.iconOnly)
            }
            Tab(value: CaseTabBarItem.floorPlan) {
                NavigationStack { floorPlan }
                    .toolbarVisibility(tabBarVisibility, for: .tabBar)
            } label: {
                Text(CaseTabCopy.floorPlan)
            }
            Tab(value: CaseTabBarItem.album) {
                NavigationStack { album }
                    .toolbarVisibility(tabBarVisibility, for: .tabBar)
            } label: {
                Text(CaseTabCopy.album)
            }
            .badge(albumBadge)
            Tab(value: CaseTabBarItem.memo) {
                NavigationStack { memo }
                    .toolbarVisibility(tabBarVisibility, for: .tabBar)
            } label: {
                Text(CaseTabCopy.memo)
            }
        }
        .tabViewStyle(.tabBarOnly)
        .onChange(of: selection) { _, newSelection in
            lastSelections[tabBarItem(of: newSelection)] = newSelection
        }
    }
}

// 탭 막대
extension CaseTabView {
    /// 사이드바를 열면 탭 막대를 숨긴다. 탭 막대는 TabView가 아니라 탭 안쪽 화면에 붙여야 숨는다.
    /// 닫기 버튼은 사이드바 윗줄에 있어서 막다른 길이 되지 않는다
    private var tabBarVisibility: Visibility {
        isSidebarShown ? .hidden : .automatic
    }

    /// 왼쪽 위 줄이 쓸 수 있는 너비.
    /// 사이드바를 접었을 때는 가운데 놓인 탭 막대의 왼쪽 끝에서 여백만큼 앞까지,
    /// 열었을 때는 탭 막대가 숨어 있으니 오른쪽 버튼 묶음 앞까지
    private func headerMaxWidth(in width: CGFloat) -> CGFloat {
        if isSidebarShown {
            return max(0, width - CaseTabLayout.actionBarWidth - CaseTabLayout.headerLeading - CaseTabLayout.headerGap)
        }
        return max(0, (width - CaseTabLayout.tabBarWidth) / 2 - CaseTabLayout.headerLeading - CaseTabLayout.headerGap)
    }

    /// 탭 막대에서 켜지는 탭은 고른 줄이 속한 구역이다.
    /// 사이드바 버튼을 누르면 탭은 그대로 두고 사이드바만 열고 닫는다
    private var tabBarSelection: Binding<CaseTabBarItem> {
        Binding(
            get: { tabBarItem(of: selection) },
            set: { newItem in
                if newItem == .sidebar {
                    toggleSidebar()
                } else {
                    selection = lastSelections[newItem] ?? firstSelection(of: newItem)
                }
            }
        )
    }

    private func tabBarItem(of selection: CaseTabSelection) -> CaseTabBarItem {
        switch selection {
        case .floorPlan2D, .floorPlan3D: .floorPlan
        case .albumOverview, .album: .album
        case .memo: .memo
        }
    }

    /// 아직 고른 적 없는 탭으로 갈 때 고를 줄: 도면은 2D, 앨범은 전체, 메모는 첫 줄
    private func firstSelection(of item: CaseTabBarItem) -> CaseTabSelection {
        switch item {
        case .sidebar, .floorPlan:
            return .floorPlan2D
        case .album:
            return .albumOverview
        case .memo:
            guard let firstRow = memoRows.first else { return selection }
            return .memo(firstRow.name)
        }
    }

    private func toggleSidebar() {
        withAnimation {
            isSidebarShown.toggle()
        }
    }
}

/// 탭 막대의 칸: 사이드바 버튼과 도면·앨범·메모
private enum CaseTabBarItem {
    case sidebar, floorPlan, album, memo
}

// 문구. 사이드바(CaseSidebar)와 함께 쓴다. 제네릭 타입 안에는 static 값을 둘 수 없어 파일 안에 따로 둔다
/// 탭 위에 겹치는 줄의 자리 (pt). 시스템 상단 바 버튼과 같은 줄에 오게 맞춘다
private enum CaseTabLayout {
    static let headerLeading: CGFloat = 16
    static let headerTop: CGFloat = 4
    /// 가운데 탭 막대(사이드바·도면·앨범·메모)의 대략 너비
    static let tabBarWidth: CGFloat = 250
    // TEMP: 실측 전 대략 값. 오른쪽 버튼 묶음(메모·사진 캡슐, 수정, 내보내기)이 차지하는 너비
    static let actionBarWidth: CGFloat = 280
    /// 왼쪽 위 줄과 탭 막대 사이 여백
    static let headerGap: CGFloat = 16
}

enum CaseTabCopy {
    static let floorPlan = "도면"
    static let album = "앨범"
    static let memo = "메모"
    static let twoD = "2D"
    static let threeD = "3D"
    static let edit = "편집"
    static let done = "완료"
    static let sidebar = "사이드바"
    static let closeSidebar = "사이드바 닫기"
    static let cancel = "취소"
    static let delete = "삭제"

    // 앨범 삭제 확인 창 (Figma). 앨범 줄은 남고 그 안의 사진만 지워진다
    static func clearAlbumTitle(_ name: String) -> String { "'\(name)' 사진을 모두 삭제할까요?" }
    static func clearAlbumMessage(_ name: String, _ count: Int) -> String {
        "현재 조사 차수의 \(name) 사진 \(count)장이 모두 삭제됩니다."
    }

    // TEMP: 메모 삭제 확인 창은 Figma에 없어 앨범 문구를 본떠 임시로 씀 — 디자인이 나오면 바꿔야 함
    static func clearMemoTitle(_ name: String) -> String { "'\(name)' 메모를 모두 삭제할까요?" }
    static func clearMemoMessage(_ name: String, _ count: Int) -> String {
        "현재 조사 차수의 \(name) 메모 \(count)개가 모두 삭제됩니다."
    }
}

#Preview {
    @Previewable @State var selection = CaseTabSelection.floorPlan2D

    CaseTabView(
        selection: $selection,
        albumRows: [CaseSidebarRow(name: "거실", systemImage: "lamp.floor", count: 89)],
        memoRows: [CaseSidebarRow(name: "거실", systemImage: "lamp.floor", count: 5)],
        onClearRow: { _ in }
    ) {
        Text("도면 내용")
    } album: {
        Text("앨범 내용")
    } memo: {
        Text("메모 내용")
    }
}

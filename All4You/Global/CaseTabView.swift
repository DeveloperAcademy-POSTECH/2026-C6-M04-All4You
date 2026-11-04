// 사건 화면 가운데의 도면·앨범·메모 탭 막대와 왼쪽 사이드바. 각 탭의 내용은 화면이 넘겨준다.
// 상단 바(CaseTitleToolbar, CaseActionToolbar)와 따로 쓸 수 있다

import SwiftUI

/// 사이드바 앨범·메모 구역의 한 줄. 장소 이름과 그 장소의 사진 수 또는 메모 수
struct CaseSidebarRow: Hashable {
    let name: String
    let systemImage: String
    let count: Int
}

/// 사이드바에서 고른 줄. 탭 막대의 도면·앨범·메모는 이 줄이 속한 구역이다
enum CaseTabSelection: Hashable {
    case floorPlan2D
    case floorPlan3D
    // TODO: 장소 데이터가 생기면 이름 대신 Room.id로 구분
    case album(String)
    case memo(String)
}

/// 도면·앨범·메모 탭 막대와 사이드바. 탭 막대 왼쪽 버튼으로 사이드바를 열고 닫는다.
/// 사이드바 구역(TabSection)이 탭 막대에서는 도면·앨범·메모 탭 하나씩으로 보인다.
/// 탭마다 상단 바(NavigationStack)를 따로 두어야 iPad에서 탭 막대가 상단 바와 같은 줄에 놓인다.
/// 그래서 이 뷰는 화면 더미 안에 넣지 말고, 상단 바 버튼(toolbar)은 각 탭 내용에 붙인다
struct CaseTabView<FloorPlan: View, Album: View, Memo: View>: View {
    @Binding var selection: CaseTabSelection
    let albumRows: [CaseSidebarRow]
    let memoRows: [CaseSidebarRow]
    @ViewBuilder let floorPlan: FloorPlan
    @ViewBuilder let album: Album
    @ViewBuilder let memo: Memo

    // 사이드바 "편집"으로 줄을 숨기거나 순서를 바꾼 상태
    @State private var customization = TabViewCustomization()

    var body: some View {
        TabView(selection: $selection) {
            TabSection(CaseTabCopy.floorPlan) {
                Tab(CaseTabCopy.twoD, systemImage: "square.on.square", value: CaseTabSelection.floorPlan2D) {
                    NavigationStack { floorPlan }
                }
                .customizationID(CaseTabCopy.twoD)
                Tab(CaseTabCopy.threeD, systemImage: "point.3.connected.trianglepath.dotted", value: CaseTabSelection.floorPlan3D) {
                    NavigationStack { floorPlan }
                }
                .customizationID(CaseTabCopy.threeD)
            }
            TabSection(CaseTabCopy.album) {
                ForEach(albumRows, id: \.self) { row in
                    Tab(row.name, systemImage: row.systemImage, value: CaseTabSelection.album(row.name)) {
                        NavigationStack { album }
                    }
                    .badge(row.count)
                    .customizationID(CaseTabCopy.album + row.name)
                }
            }
            TabSection(CaseTabCopy.memo) {
                ForEach(memoRows, id: \.self) { row in
                    Tab(row.name, systemImage: row.systemImage, value: CaseTabSelection.memo(row.name)) {
                        NavigationStack { memo }
                    }
                    .badge(row.count)
                    .customizationID(CaseTabCopy.memo + row.name)
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabViewCustomization($customization)
    }
}

// 문구. 제네릭 타입 안에는 static 값을 둘 수 없어 파일 안에 따로 둔다
private enum CaseTabCopy {
    static let floorPlan = "도면"
    static let album = "앨범"
    static let memo = "메모"
    static let twoD = "2D"
    static let threeD = "3D"
}

#Preview {
    @Previewable @State var selection = CaseTabSelection.floorPlan2D

    CaseTabView(
        selection: $selection,
        albumRows: [CaseSidebarRow(name: "거실", systemImage: "lamp.floor", count: 89)],
        memoRows: [CaseSidebarRow(name: "거실", systemImage: "lamp.floor", count: 5)]
    ) {
        Text("도면 내용")
    } album: {
        Text("앨범 내용")
    } memo: {
        Text("메모 내용")
    }
}

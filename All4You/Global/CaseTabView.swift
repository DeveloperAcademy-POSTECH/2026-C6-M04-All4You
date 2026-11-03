// 사건 화면 가운데의 도면·앨범·메모 탭 막대. 각 탭의 내용은 화면이 넘겨준다.
// 상단 바(CaseTitleToolbar, CaseActionToolbar)와 따로 쓸 수 있다

import SwiftUI

/// 도면·앨범·메모 탭 막대. 탭을 누르면 화면이 넘겨준 그 탭의 내용으로 바뀐다.
/// 탭마다 상단 바(NavigationStack)를 따로 두어야 iPad에서 탭 막대가 상단 바와 같은 줄에 놓인다.
/// 그래서 이 뷰는 화면 더미 안에 넣지 말고, 상단 바 버튼(toolbar)은 각 탭 내용에 붙인다
struct CaseTabView<FloorPlan: View, Album: View, Memo: View>: View {
    @ViewBuilder let floorPlan: FloorPlan
    @ViewBuilder let album: Album
    @ViewBuilder let memo: Memo

    var body: some View {
        // 아이콘은 접근성/사이드바에 들어가는 역할이라 불필요하다는 피드백 오면 삭제 예정
        TabView {
            Tab(CaseTabCopy.floorPlan, systemImage: "map") {
                NavigationStack { floorPlan }
            }
            Tab(CaseTabCopy.album, systemImage: "photo.on.rectangle") {
                NavigationStack { album }
            }
            Tab(CaseTabCopy.memo, systemImage: "note.text") {
                NavigationStack { memo }
            }
        }
    }
}

// 문구. 제네릭 타입 안에는 static 값을 둘 수 없어 파일 안에 따로 둔다
private enum CaseTabCopy {
    static let floorPlan = "도면"
    static let album = "앨범"
    static let memo = "메모"
}

#Preview {
    CaseTabView {
        Text("도면 내용")
    } album: {
        Text("앨범 내용")
    } memo: {
        Text("메모 내용")
    }
}

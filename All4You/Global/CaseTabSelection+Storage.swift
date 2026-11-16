// 사건 메인에서 고른 탭(CaseTabSelection)을 사건에 저장하고 다시 읽는 변환. 앱을 껐다 켜거나 사건을 다시 열 때 보던 탭으로 열려고 쓴다

import Foundation

extension CaseTabSelection {
    /// FireCase.lastViewedTab에 저장하는 글자. 앨범·메모 줄은 장소 이름을 뒤에 붙인다
    var storageValue: String {
        switch self {
        case .floorPlan2D: Prefix.floorPlan2D
        case .floorPlan3D: Prefix.floorPlan3D
        case .albumOverview: Prefix.albumOverview
        case .album(let name): Prefix.album + name
        case .memo(let name): Prefix.memo + name
        }
    }

    /// 저장된 글자에서 탭을 읽는다. 알 수 없는 글자면 nil
    init?(storageValue: String) {
        switch storageValue {
        case Prefix.floorPlan2D: self = .floorPlan2D
        case Prefix.floorPlan3D: self = .floorPlan3D
        case Prefix.albumOverview: self = .albumOverview
        default:
            if storageValue.hasPrefix(Prefix.album) {
                self = .album(String(storageValue.dropFirst(Prefix.album.count)))
            } else if storageValue.hasPrefix(Prefix.memo) {
                self = .memo(String(storageValue.dropFirst(Prefix.memo.count)))
            } else {
                return nil
            }
        }
    }

    private enum Prefix {
        static let floorPlan2D = "floorPlan2D"
        static let floorPlan3D = "floorPlan3D"
        static let albumOverview = "albumOverview"
        static let album = "album:"
        static let memo = "memo:"
    }
}

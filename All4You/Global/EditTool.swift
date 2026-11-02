// 수정 화면의 상단 도구 막대에서 고를 수 있는 도구 목록

/// 상단 도구 막대의 도구 하나. 선언한 순서대로 막대에 놓인다
enum EditTool: CaseIterable {
    case ignitionPoint, electrical, victim, roomName, furniture, window

    var title: String {
        switch self {
        case .ignitionPoint: "발화지점"
        case .electrical: "전기"
        case .victim: "피해자"
        case .roomName: "공간이름"
        case .furniture: "가구"
        case .window: "창문"
        }
    }

    var iconName: String {
        switch self {
        case .ignitionPoint: "flame.fill"
        case .electrical: "bolt.fill"
        case .victim: "figure.fall"
        case .roomName: "character.textbox"
        case .furniture: "sofa"
        case .window: "window.casement"
        }
    }
}

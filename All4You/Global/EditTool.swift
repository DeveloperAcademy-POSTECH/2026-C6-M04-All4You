// 수정 화면의 상단 도구 막대에서 고를 수 있는 도구 목록

/// 상단 도구 막대의 도구 하나. 선언한 순서대로 막대에 놓인다
enum EditTool: CaseIterable {
    case ignitionPoint, electrical, victim, roomName, furniture, window

    private var details: (title: String, iconName: String) {
        switch self {
        case .ignitionPoint: ("발화지점", "flame.fill")
        case .electrical:    ("전기", "bolt.fill")
        case .victim:        ("피해자", "figure.fall")
        case .roomName:      ("공간이름", "character.textbox")
        case .furniture:     ("가구", "sofa")
        case .window:        ("창문", "window.casement")
        }
    }

    var title: String { details.title }
    var iconName: String { details.iconName }
}

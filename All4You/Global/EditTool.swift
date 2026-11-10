// 수정 화면의 상단 도구 막대에서 고를 수 있는 도구 목록

/// 상단 도구 막대의 도구 하나. 선언한 순서대로 막대에 놓인다
/// 스탬프 도구의 이름은 도면 데이터의 종류 이름을 따른다: 발화지점·사람(ignitionPoint, person)은 MarkerKind, 콘센트(outlet)는 FixtureKind, 창문·문(window, door)은 DoorWindowKind
enum EditTool: CaseIterable {
    case ignitionPoint, outlet, person, roomName, furniture, window, door

    private var details: (title: String, iconName: String) {
        switch self {
        case .ignitionPoint: ("발화지점", "flame.fill")
        case .outlet:        ("전기", "bolt.fill")
        case .person:        ("피해자", "figure.stand")
        case .roomName:      ("공간라벨", "a.square.fill")
        case .furniture:     ("가구라벨", "a.square")
        case .window:        ("창문", "rectangle")
        case .door:          ("문", "button.angledtop.vertical.left")
        }
    }

    var title: String { details.title }
    var iconName: String { details.iconName }
}

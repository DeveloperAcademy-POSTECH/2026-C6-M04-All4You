// 스탬프의 세부 종류. 발화지점은 발화원인, 전기는 전기 종류를 고르고, 도면의 스탬프 아래에 글자 라벨로 보인다

/// 발화원인. 발화지점(PlanMarker.ignitionCause)에 값이 있다
enum IgnitionCause: String, Codable, CaseIterable {
    case electrical
    case arson
    case gas
    case mechanical
    case carelessness
    case other

    /// 화면 글자
    var title: String {
        switch self {
        case .electrical: "전기"
        case .arson: "방화"
        case .gas: "가스"
        case .mechanical: "기계"
        case .carelessness: "인적 부주의"
        case .other: "기타"
        }
    }
}

/// 전기 종류. 바닥 전기(PlanMarker.electricalKind)와 벽 전기(WallFixture.electricalKind)에 값이 있다
enum ElectricalKind: String, Codable, CaseIterable {
    case powerStrip
    case circuitBreaker
    case wireBundle
    case outlet
    case other

    /// 화면 글자
    var title: String {
        switch self {
        case .powerStrip: "멀티탭"
        case .circuitBreaker: "누전차단기"
        case .wireBundle: "전선다발"
        case .outlet: "콘센트"
        case .other: "기타"
        }
    }
}

/// 도구 막대에서 고른 종류. 도구(발화지점·전기)마다 고를 수 있는 종류가 다르다. 화면 상태라 저장하지 않는다
enum StampOption: Hashable {
    case ignitionCause(IgnitionCause)
    case electricalKind(ElectricalKind)

    /// 화면 글자
    var title: String {
        switch self {
        case .ignitionCause(let cause): cause.title
        case .electricalKind(let kind): kind.title
        }
    }
}

extension EditTool {
    /// 이 도구에서 고를 수 있는 종류들. 비어 있으면 종류를 고르지 않고 바로 놓는다
    var stampOptions: [StampOption] {
        switch self {
        case .ignitionPoint: IgnitionCause.allCases.map(StampOption.ignitionCause)
        case .outlet: ElectricalKind.allCases.map(StampOption.electricalKind)
        case .person, .roomName, .furniture, .window, .door: []
        }
    }
}

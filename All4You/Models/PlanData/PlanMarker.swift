// 도면 위에 놓는 사람·발화지점·바닥 전기요소 표시 planData.markers 스탬프. 벽에 붙는 콘센트(WallFixture)와 성격이 달라 분리.

/// 바닥 위 위치·높이와 바라보는 방향을 가진 표시. 2D에서는 기호, 3D에서는 모델로 그린다
struct PlanMarker: Codable, Hashable, Identifiable {
    let id: String
    var kind: MarkerKind
    /// 도면 좌표 (x, y) (m). JSON에는 [x, y] 배열로 저장된다
    var position: SIMD2<Double>
    /// 바닥에서 높이 (m)
    var height: Double
    /// 바라보는 방향 (도). 도면 위쪽이 0°, 시계 방향으로 커진다
    var yaw: Double
    /// 누운 자세 (사람만, 나머지는 nil)
    var lying: Bool?
    /// 기본 크기에 곱하는 배율. nil이면 1 (이 칸이 생기기 전에 저장한 도면도 그대로 읽히게 옵셔널)
    var scale: Double?
    /// 발화원인 (발화지점만 값이 있고 나머지는 nil. 이 칸이 생기기 전에 저장한 도면도 그대로 읽히게 옵셔널)
    var ignitionCause: IgnitionCause? = nil
    /// 전기 종류 (바닥 전기만 값이 있고 나머지는 nil)
    var electricalKind: ElectricalKind? = nil
    /// 종류가 기타(other)일 때 사용자가 적은 라벨 글자. 없으면 "기타"로 보인다 (이 칸이 생기기 전에 저장한 도면도 그대로 읽히게 옵셔널)
    var kindNote: String? = nil

    /// 그릴 때 쓰는 배율. 저장된 값이 없으면 1
    var drawScale: Double { scale ?? 1 }

    /// 사람은 실제 사람 크기(누운 몸 1.5m)가 아니라 발화지점·콘센트와 같은 기호 크기(약 0.6m)로 그린다.
    /// 2D 아이콘은 이 몸 길이에 맞춰 그려서, 사람만 2D에서 유독 커 보이지 않게 한다
    static let personTokenScale = 0.4

    /// 3D에서만 사람 모델을 기호 크기보다 더 키우는 배수. 2D 아이콘과 놓을 수 있는 자리(footprint)는 그대로다
    // TEMP: 3D에서 피해자가 작아 보여 임시로 정한 값 — 실기기에서 보고 조절
    static let personModelEnlargement = 1.5

    /// 3D에서 사람 모델에 곱하는 배수 (기호 크기 × 3D 확대). 사람이 아니면 1
    static func modelFactor(of kind: MarkerKind) -> Double {
        kind == .person ? personTokenScale * personModelEnlargement : 1
    }

    /// 종류가 기타라 라벨 글자를 직접 적을 수 있는지
    var isKindOther: Bool {
        switch kind {
        case .ignitionPoint: ignitionCause == .other
        case .outlet: electricalKind == .other
        case .person: false
        }
    }

    /// 스탬프 아래에 보일 글자. 발화지점·전기는 고른 종류(종류를 고르지 않은 예전 스탬프는 nil), 피해자는 "피해자".
    /// 종류가 기타이고 적은 글자(kindNote)가 있으면 그 글자
    var kindLabel: String? {
        if isKindOther, let kindNote { return kindNote }
        return switch kind {
        case .ignitionPoint: ignitionCause?.title
        case .outlet: electricalKind?.title
        case .person: EditTool.person.title
        }
    }

    /// 3D 모델에 곱하는 배율
    var modelScale: Double { drawScale * Self.modelFactor(of: kind) }
}

/// 표시 종류
enum MarkerKind: String, Codable {
    /// 사람 (화면 글자 "피해자")
    case person
    /// 발화지점
    case ignitionPoint
    /// 바닥에 놓인 전기요소 (멀티탭·바닥 콘센트 등, 화면 글자 "전기"). 벽에 붙은 콘센트는 `WallFixture`
    case outlet

    /// 가구 위에 놓이면 가구 윗면 위로 올라오는지. 전기는 가구 밑에 있을 수 있어 가구와 상관없이 바닥에 둔다
    var sitsOnFurniture: Bool { self != .outlet }
}

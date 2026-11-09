// 바닥에 놓인 가구 planData.furniture. 공간 스캔의 물체와 서버 도면의 가구 상자가 여기로 바뀐다

import Foundation

/// 중심·크기·회전으로 저장하는 가구 하나. 2D에서는 윗면 모양, 3D에서는 상자로 그린다
struct Furniture: Codable, Hashable, Identifiable {
    let id: String
    /// 화면에 보이는 이름 (예: "냉장고"). 사용자가 바꿀 수 있다
    var label: String
    /// 공간 스캔이 알려 준 물체 종류 (예: "refrigerator"). 서버 도면에서 온 가구는 nil
    var category: String?
    var shape: FurnitureShape
    /// 도면 좌표 (x, y) (m). JSON에는 [x, y] 배열로 저장된다
    var center: SIMD2<Double>
    /// 회전하기 전 가로 길이 (m). 원형은 지름
    var width: Double
    /// 회전하기 전 세로 길이 (m). 원형은 지름
    var depth: Double
    /// 회전 (라디안). 도면에서 시계 방향으로 커진다. 스탬프의 yaw(도)와 단위가 다르다
    var rotation: Double
    /// 가구 자체 높이 (m)
    var height: Double
    /// 바닥에서 아래 끝까지 띄운 높이 (m)
    var elevation: Double
}

/// 가구 윗면 모양
enum FurnitureShape: String, Codable {
    /// 사각형
    case rectangle
    /// 원형 (width = depth = 지름)
    case circle
}

extension Furniture {
    /// 사각형의 네 모서리 (도면 좌표). 회전한 가로 방향은 (cos, sin), 세로 방향은 그것을 시계 방향으로 90° 돌린 쪽
    var corners: [SIMD2<Double>] {
        let across = SIMD2(cos(rotation), sin(rotation)) * (width / 2)
        let along = SIMD2(-sin(rotation), cos(rotation)) * (depth / 2)
        return [center - across - along, center + across - along, center + across + along, center - across + along]
    }
}

extension Furniture {
    /// 공간 스캔 물체 종류 → 화면 이름. 종류 이름은 RoomPlan이 쓰는 영어 이름 그대로
    private static let categoryLabels: [String: String] = [
        "storage": "수납장", "refrigerator": "냉장고", "stove": "레인지", "bed": "침대",
        "sink": "싱크대", "washerDryer": "세탁기·건조기", "toilet": "변기", "bathtub": "욕조",
        "oven": "오븐", "dishwasher": "식기세척기", "table": "테이블", "sofa": "소파",
        "chair": "의자", "fireplace": "벽난로", "television": "TV", "stairs": "계단",
    ]

    /// 물체 종류의 한국어 이름. 표에 없는 종류는 "가구"
    static func label(forCategory category: String) -> String {
        categoryLabels[category] ?? "가구"
    }
}

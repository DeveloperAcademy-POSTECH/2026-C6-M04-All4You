// 2D·3D가 함께 보는 도면 하나. planData에 JSON으로 저장되는 값(외부 모델에서 받아오는 형식, RoomPlan 데이터도 이 형식으로 변환해서 통일 예정)
//
// 좌표 규칙: 단위 m, 원점 = 도면 왼쪽 위, +x = 오른쪽, +y = 아래쪽, 높이 = 바닥에서 위로(추후 수정 가능성 존재)
// 도면 위 요소끼리는 문자열 id로 서로 가리킨다 (벽 → 꼭짓점 id, 문·창문·콘센트 → 벽 id, 방 → 벽 id)

/// 도면 하나. 값 타입이라 복사한 값이 그대로 그 순간의 스냅샷이 된다
struct PlanData: Codable, Hashable {
    /// 형식 버전. 새 항목은 옵셔널로 추가해 이전에 저장한 도면도 그대로 읽히게 한다
    var version: Int
    var vertices: [Vertex]
    var walls: [Wall]
    var doorWindows: [DoorWindow]
    var wallFixtures: [WallFixture]
    var rooms: [Room]
    var markers: [PlanMarker]
    /// 가구. 이 칸이 생기기 전에 저장한 도면도 그대로 읽히게 옵셔널
    var furniture: [Furniture]? = nil
    /// 공간 스캔 월드 좌표 → 도면 좌표 변환 (바닥 높이 포함). 스캔으로 만든 도면만 있다.
    /// 스캔·AR 촬영 사진의 카메라 자세를 도면 위치·방향으로 바꿀 때 쓴다
    var scanAlignment: ScanAlignment? = nil
}

extension PlanData {
    /// 아무것도 없는 도면
    static let empty = PlanData(version: 1, vertices: [], walls: [], doorWindows: [], wallFixtures: [], rooms: [], markers: [])
}

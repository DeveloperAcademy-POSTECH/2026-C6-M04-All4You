// 2D·3D가 함께 보는 도면 하나. planData에 JSON으로 저장되는 값(외부 모델에서 받아오는 형식, RoomPlan 데이터도 이 형식으로 변환해서 통일 예정)
//
// 좌표 규칙: 단위 m, 원점 = 도면 왼쪽 위, +x = 오른쪽, +y = 아래쪽, 높이 = 바닥에서 위로(추후 수정 가능성 존재)
// 도면 위 요소끼리는 문자열 id로 서로 가리킨다 (벽 → 꼭짓점 id, 문·창문·콘센트 → 벽 id). 공간 라벨은 id로 가리키지 않고 자리(점)만 갖는다

/// 도면 하나. 값 타입이라 복사한 값이 그대로 그 순간의 스냅샷이 된다
struct PlanData: Codable, Hashable {
    /// 형식 버전 (지금 2). 새 항목은 옵셔널로 추가해 같은 버전에 저장한 도면도 그대로 읽히게 한다. 옛 버전은 PlanDataMigration이 읽을 때 바꾼다
    var version: Int
    var vertices: [Vertex]
    var walls: [Wall]
    var doorWindows: [DoorWindow]
    var wallFixtures: [WallFixture]
    var rooms: [Room]
    var markers: [PlanMarker]
    /// 가구. 이 칸이 생기기 전에 저장한 도면도 그대로 읽히게 옵셔널
    var furniture: [Furniture]? = nil
    // TEMP: floors·northAngle·planRotation은 ERD에 없는 값이라 PlanData에 먼저 둠 — ERD 반영 때 이름·자리가 바뀔 수 있음
    /// 스캔한 바닥. 벽과 별개로 저장해 항상 그린다. 스캔이 아닌 도면은 nil, 이 칸이 생기기 전에 저장한 도면도 읽히게 옵셔널
    var floors: [Floor]? = nil
    /// 공간 스캔 월드 좌표 → 도면 좌표 변환 (바닥 높이 포함). 스캔으로 만든 도면만 있다.
    /// 스캔·AR 촬영 사진의 카메라 자세를 도면 위치·방향으로 바꿀 때 쓴다
    var scanAlignment: ScanAlignment? = nil
    /// 도면 위쪽에서 북쪽까지 시계 방향으로 잰 각 (라디안). 방위표를 돌려 정한다. 이 칸이 생기기 전에 저장한 도면도 읽히게 옵셔널이고, nil이면 도면 위쪽이 북쪽이다
    var northAngle: Double? = nil
    /// 2D에서 도면을 시계 방향으로 돌려 둔 각 (라디안). 2D 화면·내보내기·미리보기가 이 각으로 도면을 보여 준다. 3D는 카메라로 돌려 보므로 쓰지 않는다. nil이면 돌리지 않은 도면
    var planRotation: Double? = nil
}

extension PlanData {
    /// 지금 형식 버전
    static let currentVersion = 2

    /// 아무것도 없는 도면
    static let empty = PlanData(version: PlanData.currentVersion, vertices: [], walls: [], doorWindows: [], wallFixtures: [], rooms: [], markers: [])
}

// 2D·3D가 함께 보는 도면 하나. planData에 JSON으로 저장되는 값(외부 모델에서 받아오는 형식, RoomPlan 데이터도 이 형식으로 변환해서 통일 예정)
//
// 좌표 규칙: 단위 m, 원점 = 도면 왼쪽 위, +x = 오른쪽, +y = 아래쪽, 높이 = 바닥에서 위로(추후 수정 가능성 존재)
// 도면 위 요소끼리는 문자열 id로 서로 가리킨다 (벽 → 꼭짓점 id, 문·창문·콘센트 → 벽 id, 방 → 벽 id)
// TEMP: 구조체 이름은 변경 가능성 존재
// TEMP: 이번 구간에 쓰는 항목만 둠. furniture(가구)·captureAlignments(사진 정렬)·floorHeightInWorld(RoomPlan 바닥 높이)는 그 작업 때 옵셔널로 추가

/// 도면 하나. 값 타입이라 복사한 값이 그대로 그 순간의 스냅샷이 된다
struct PlanData: Codable, Equatable {
    /// 형식 버전. 새 항목은 옵셔널로 추가해 이전에 저장한 도면도 그대로 읽히게 한다
    var version: Int
    var vertices: [Vertex]
    var walls: [Wall]
    var doorWindows: [DoorWindow]
    var wallFixtures: [WallFixture]
    var rooms: [Room]
    var markers: [PlanMarker]
}

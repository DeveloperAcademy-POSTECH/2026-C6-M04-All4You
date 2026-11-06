// 2D·3D가 함께 보는 도면 하나. ERD v16(ERD_1106_수정본.md)의 FLOOR_PLAN.planData에 JSON으로 저장되는 값
//
// 좌표 규칙 (ERD 3-1): 단위 m, 원점 = 도면 왼쪽 위, +x = 오른쪽, +y = 아래쪽, 높이 = 바닥에서 위로
// 도면 위 요소끼리는 문자열 id로 서로 가리킨다 (벽 → 꼭짓점 id, 문·창문·콘센트 → 벽 id, 방 → 벽 id)
// TEMP: ERD v16은 이 구조체 이름을 FloorPlan으로 적었지만, 같은 이름의 테이블(FLOOR_PLAN)과 겹쳐 칸 이름(planData)을 따라 PlanData로 함 — 팀이 ERD를 정하면 맞춤
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

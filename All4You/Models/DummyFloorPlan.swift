// 화면 확인용 더미 도면 하나. 추후 삭제 예정(기능 확인용 임시 더미데이터).
// TEMP: 도면을 만들고 저장하는 흐름(RoomPlan·외부 도면 변환, SwiftData 저장)이 연결되기 전 임시 값
// 도면 모양 (도면 좌표, m. 원점 = 왼쪽 위, +y = 아래)
//   v1(0.5, 0.5) ── w1 ── v2(6.5, 0.5)
//    │                      │
//   w7   r1 거실·주방       w2   ← 콘센트 f1, 그 앞에 발화지점 m2
//    │                      │
//   v5(0.5, 4.5) ── w5 ── v6(6.5, 4.5)   ← w5 = 가운데 안쪽 벽, 침실 문 d3
//    │                      │
//   w6   r2 침실 (사람 m1)  w3
//    │                      │
//   v4(0.5, 7.5) ── w4 ── v3(6.5, 7.5)

enum DummyFloorPlan {
    static let planData = PlanData(
        version: 1,
        vertices: vertices,
        walls: walls,
        doorWindows: doorWindows,
        wallFixtures: wallFixtures,
        rooms: rooms,
        markers: markers,
        furniture: furniture
    )
}

// 벽과 꼭짓점
extension DummyFloorPlan {
    private static let vertices = [
        Vertex(id: "v1", x: 0.5, y: 0.5),
        Vertex(id: "v2", x: 6.5, y: 0.5),
        Vertex(id: "v3", x: 6.5, y: 7.5),
        Vertex(id: "v4", x: 0.5, y: 7.5),
        Vertex(id: "v5", x: 0.5, y: 4.5),
        Vertex(id: "v6", x: 6.5, y: 4.5)
    ]

    private static let walls = [
        outerWall(id: "w1", from: "v1", to: "v2"),
        outerWall(id: "w2", from: "v2", to: "v6"),
        outerWall(id: "w3", from: "v6", to: "v3"),
        outerWall(id: "w4", from: "v3", to: "v4"),
        Wall(id: "w5", startVertex: "v6", endVertex: "v5", thickness: 0.1, height: 2.4, isVirtual: false),
        outerWall(id: "w6", from: "v4", to: "v5"),
        outerWall(id: "w7", from: "v5", to: "v1")
    ]

    private static func outerWall(id: String, from start: String, to end: String) -> Wall {
        Wall(id: id, startVertex: start, endVertex: end, thickness: 0.15, height: 2.4, isVirtual: false)
    }
}

// 벽에 달린 것
extension DummyFloorPlan {
    private static let doorWindows = [
        DoorWindow(id: "d1", wallId: "w1", kind: .door, centerAlongWall: 1.2, width: 0.9, sillHeight: 0, height: 2.0),
        DoorWindow(id: "d2", wallId: "w1", kind: .window, centerAlongWall: 3.5, width: 1.5, sillHeight: 0.9, height: 1.2),
        DoorWindow(id: "d3", wallId: "w5", kind: .door, centerAlongWall: 3.0, width: 0.9, sillHeight: 0, height: 2.0),
        DoorWindow(id: "d4", wallId: "w4", kind: .window, centerAlongWall: 3.0, width: 1.2, sillHeight: 0.9, height: 1.2)
    ]

    /// f1은 오른쪽 벽 w2(위 → 아래)의 오른쪽 면 = 집 안쪽 면
    private static let wallFixtures = [
        WallFixture(id: "f1", wallId: "w2", kind: .outlet, face: .right, positionAlongWall: 1.6, heightFromFloor: 0.3)
    ]
}

// 장소와 표시
extension DummyFloorPlan {
    private static let rooms = [
        Room(
            id: "r1",
            name: "거실·주방",
            boundary: [
                RoomEdge(wallId: "w1", forward: true),
                RoomEdge(wallId: "w2", forward: true),
                RoomEdge(wallId: "w5", forward: true),
                RoomEdge(wallId: "w7", forward: true)
            ],
            labelX: 3.0,
            labelY: 2.0
        ),
        Room(
            id: "r2",
            name: "침실",
            boundary: [
                RoomEdge(wallId: "w5", forward: false),
                RoomEdge(wallId: "w3", forward: true),
                RoomEdge(wallId: "w4", forward: true),
                RoomEdge(wallId: "w6", forward: true)
            ],
            labelX: 3.5,
            labelY: 6.0
        )
    ]

    private static let markers = [
        PlanMarker(id: "m1", kind: .person, position: [3.0, 5.8], height: 0.5, yaw: 180, lying: true),
        PlanMarker(id: "m2", kind: .ignitionPoint, position: [6.2, 2.1], height: 0.3, yaw: 0, lying: nil)
    ]

    /// 사각형·원형, 돌린 가구, 바닥에서 띄운 가구(벽 수납장)를 하나씩
    private static let furniture = [
        Furniture(id: "u1", label: "소파", category: "sofa", shape: .rectangle, center: [2.0, 3.6], width: 2.0, depth: 0.9, rotation: 0, height: 0.8, elevation: 0),
        Furniture(id: "u2", label: "냉장고", category: "refrigerator", shape: .rectangle, center: [5.9, 1.0], width: 0.8, depth: 0.7, rotation: .pi / 2, height: 1.8, elevation: 0),
        Furniture(id: "u3", label: "식탁", category: nil, shape: .circle, center: [4.2, 2.8], width: 1.0, depth: 1.0, rotation: 0, height: 0.75, elevation: 0),
        Furniture(id: "u4", label: "수납장", category: "storage", shape: .rectangle, center: [1.4, 7.2], width: 1.2, depth: 0.4, rotation: 0, height: 0.6, elevation: 1.4)
    ]
}

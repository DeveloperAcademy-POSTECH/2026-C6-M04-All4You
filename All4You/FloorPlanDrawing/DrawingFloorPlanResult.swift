// 고정 결과 이미지와 같은 구조의 편집용 도면. 좌표는 이미지 기준점을 m로 환산한다.
// 스케치 획이나 스탬프는 결과에 반영하지 않는다.
enum DrawingFloorPlanResult {
    static let planData = PlanData(
        version: PlanData.currentVersion,
        vertices: [
            vertex("topLeft", 112, 130), vertex("topBed1", 727, 130),
            vertex("topBed2", 1264, 130), vertex("topRight", 1740, 130),
            vertex("middleLeft", 112, 507), vertex("middleBed1", 727, 507),
            vertex("middleBed2", 1264, 507), vertex("middleBalcony", 1511, 507),
            vertex("middleRight", 1740, 507), vertex("bottomLeft", 112, 1115),
            vertex("bottomBalcony", 1511, 1115), vertex("bottomRight", 1740, 1115)
        ],
        walls: [
            wall("top1", "topLeft", "topBed1"), wall("top2", "topBed1", "topBed2"),
            wall("top3", "topBed2", "topRight"), wall("left1", "topLeft", "middleLeft"),
            wall("left2", "middleLeft", "bottomLeft"), wall("right1", "topRight", "middleRight"),
            wall("right2", "middleRight", "bottomRight"), wall("bottom1", "bottomLeft", "bottomBalcony"),
            wall("bottom2", "bottomBalcony", "bottomRight"), wall("bedDivider1", "topBed1", "middleBed1"),
            wall("bedDivider2", "topBed2", "middleBed2"), wall("bedFront1", "middleLeft", "middleBed1"),
            wall("bedFront2", "middleBed1", "middleBed2"), wall("bathFront", "middleBed2", "middleBalcony"),
            wall("balconyTop", "middleBalcony", "middleRight"), wall("balconyDivider", "middleBalcony", "bottomBalcony")
        ],
        doorWindows: [
            opening("bedWindow", "top1", .window, center: 471.5, width: 227),
            opening("livingWindow", "bottom1", .window, center: 273.5, width: 201),
            opening("balconyWindow", "right2", .window, center: 466, width: 202),
            opening("balconyPassage", "balconyDivider", .door, center: 322, width: 278, doorStyle: .sliding),
            opening("bedDoor1", "bedFront1", .door, center: 508, width: 115),
            opening("bedDoor2", "bedFront2", .door, center: 436.5, width: 113),
            opening("bathDoor", "bathFront", .door, center: 97, width: 102),
            opening("entryDoor", "bottom1", .door, center: 857.5, width: 111)
        ],
        wallFixtures: [],
        rooms: [
            room("bed1", "방 1", 463, 310), room("bed2", "방 2", 1087, 310),
            room("bath", "욕실", 1502, 310), room("living", "거실", 897, 805),
            room("balcony", "베란다", 1626, 618)
        ],
        markers: [],
        furniture: [
            furniture("bed1", "침대", 148, 164, 350, 438, height: 0.55),
            furniture("bed2", "침대", 760, 176, 960, 448, height: 0.55),
            furniture("tv", "TV", 160, 664, 259, 897, height: 1.1),
            furniture("sofa", "소파", 537, 603, 685, 970, height: 0.8),
            furniture("table", "탁자", 1232, 686, 1378, 924, height: 0.75)
        ]
    )

    // 기준 이미지의 외벽 왼쪽 위를 원점으로, 100픽셀을 1m로 둔다.
    private static func vertex(_ id: String, _ x: Double, _ y: Double) -> Vertex {
        Vertex(id: id, x: (x - 112) / 100, y: (y - 130) / 100)
    }

    private static func wall(_ id: String, _ start: String, _ end: String) -> Wall {
        Wall(id: id, startVertex: start, endVertex: end, thickness: 0.23, height: 2.4)
    }

    private static func opening(_ id: String, _ wallId: String, _ kind: DoorWindowKind, center: Double, width: Double, doorStyle: DoorStyle? = nil) -> DoorWindow {
        DoorWindow(id: id, wallId: wallId, kind: kind, centerAlongWall: center / 100,
                   width: width / 100, sillHeight: kind == .window ? 0.9 : 0,
                   height: kind == .window ? 1.2 : 2.0, doorStyle: doorStyle)
    }

    private static func room(_ id: String, _ name: String, _ x: Double, _ y: Double) -> Room {
        Room(id: id, name: name, labelX: (x - 112) / 100, labelY: (y - 130) / 100)
    }

    private static func furniture(_ id: String, _ label: String, _ left: Double, _ top: Double,
                                  _ right: Double, _ bottom: Double, height: Double) -> Furniture {
        Furniture(id: id, label: label, category: nil, shape: .rectangle,
                  center: [(left + right - 224) / 200, (top + bottom - 260) / 200],
                  width: (right - left) / 100, depth: (bottom - top) / 100,
                  rotation: 0, height: height, elevation: 0)
    }
}

// 저장된 도면 JSON을 읽을 때 옛 형식(version 1)을 지금 형식(version 2)으로 바꾼다
//
// 달라진 점: 방(공간 라벨)이 벽 id로 닫힌 고리(boundary)를 저장하지 않고 이름과 자리(점)만 갖는다. 가상 경계선(isVirtual)은 없어지고,
// 스캔한 바닥은 벽과 별개인 floors로 저장한다.
// 읽기만 하고 저장하지 않은 도면은 version 1 그대로 남으므로, 바꾼 도면을 처음 덮어쓰기 전에 원본을 파일로 남긴다 (FloorPlan.storePlanData)

import Foundation

extension PlanData {
    /// 저장된 JSON의 형식 버전. 읽을 수 없으면 nil
    static func storedVersion(of data: Data) -> Int? {
        struct Header: Decodable { let version: Int }
        return (try? JSONDecoder().decode(Header.self, from: data))?.version
    }

    /// 저장된 JSON을 도면 값으로 읽는다. version 1은 지금 형식으로 바꿔 돌려주고,
    /// 지금 형식보다 새 버전이거나 읽지 못하면 nil (읽지 못한 도면 경로: 덮어쓰기 전에 사용자에게 묻고 파일로 남긴다)
    static func decodeStored(_ data: Data) -> PlanData? {
        switch storedVersion(of: data) {
        case currentVersion?:
            return try? JSONDecoder().decode(PlanData.self, from: data)
        case 1?:
            return (try? JSONDecoder().decode(PlanDataV1.self, from: data))?.migrated
        default:
            return nil
        }
    }
}

// 옛 형식 (읽기 전용)

/// version 1 도면. 칸 이름은 옛 형식 그대로다
private struct PlanDataV1: Decodable {
    var version: Int
    var vertices: [Vertex]
    var walls: [WallV1]
    var doorWindows: [DoorWindow]
    var wallFixtures: [WallFixture]
    var rooms: [RoomV1]
    var markers: [PlanMarker]
    var furniture: [Furniture]?
    var floors: [Floor]?
    var scanAlignment: ScanAlignment?
    var northAngle: Double?
    var planRotation: Double?
}

private struct WallV1: Decodable {
    let id: String
    var startVertex: String
    var endVertex: String
    var thickness: Double
    var height: Double
    var isVirtual: Bool

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        startVertex = try container.decode(String.self, forKey: .startVertex)
        endVertex = try container.decode(String.self, forKey: .endVertex)
        thickness = try container.decode(Double.self, forKey: .thickness)
        height = try container.decode(Double.self, forKey: .height)
        isVirtual = try container.decodeIfPresent(Bool.self, forKey: .isVirtual) ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case id, startVertex, endVertex, thickness, height, isVirtual
    }
}

private struct RoomV1: Decodable {
    let id: String
    var name: String
    var boundary: [RoomEdgeV1]?
    var labelX: Double
    var labelY: Double
}

private struct RoomEdgeV1: Decodable {
    var wallId: String
    var forward: Bool
}

// 바꾸기

extension PlanDataV1 {
    /// 지금 형식으로 바꾼 도면.
    /// - 가상 경계선은 벽에서 빼고(달린 창문·문·콘센트와, 어느 벽도 쓰지 않는 꼭짓점도), 가상 경계선이 낀 방은 그 다각형을 바닥(floors)으로 옮겨 영역을 살린다
    /// - 방은 id·이름·자리만 남긴다. 자리가 유한하지 않으면 옛 경계 다각형의 무게중심으로 둔다
    var migrated: PlanData {
        let virtualIds = Set(walls.filter(\.isVirtual).map(\.id))
        let points = Dictionary(vertices.map { ($0.id, SIMD2($0.x, $0.y)) }, uniquingKeysWith: { first, _ in first })
        let wallsById = Dictionary(walls.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        func polygon(of room: RoomV1) -> [SIMD2<Double>] {
            (room.boundary ?? []).compactMap { edge in
                guard let wall = wallsById[edge.wallId] else { return nil }
                return points[edge.forward ? wall.startVertex : wall.endVertex]
            }
        }

        // 가상 경계선이 낀 방의 다각형 → 바닥
        var movedFloors: [Floor] = []
        for room in rooms where (room.boundary ?? []).contains(where: { virtualIds.contains($0.wallId) }) {
            let outline = polygon(of: room)
            guard outline.count >= 3, abs(PlanData.signedArea(outline)) > WallMoveRules.eps else { continue }
            movedFloors.append(Floor(id: "floor-\(room.id)", corners: outline.map { FloorCorner(x: $0.x, y: $0.y) }))
        }

        let keptWalls = walls.filter { !$0.isVirtual }
        let usedVertices = Set(keptWalls.flatMap { [$0.startVertex, $0.endVertex] })
        let allFloors = (floors ?? []) + movedFloors

        return PlanData(
            version: PlanData.currentVersion,
            vertices: vertices.filter { usedVertices.contains($0.id) },
            walls: keptWalls.map { Wall(id: $0.id, startVertex: $0.startVertex, endVertex: $0.endVertex, thickness: $0.thickness, height: $0.height) },
            doorWindows: doorWindows.filter { !virtualIds.contains($0.wallId) },
            wallFixtures: wallFixtures.filter { !virtualIds.contains($0.wallId) },
            rooms: rooms.map { room in
                var x = room.labelX
                var y = room.labelY
                if !x.isFinite || !y.isFinite {
                    let outline = polygon(of: room)
                    let center = outline.isEmpty ? SIMD2<Double>.zero : outline.reduce(.zero, +) / Double(outline.count)
                    x = center.x
                    y = center.y
                }
                return Room(id: room.id, name: room.name, labelX: x, labelY: y)
            },
            markers: markers,
            furniture: furniture,
            floors: allFloors.isEmpty ? nil : allFloors,
            scanAlignment: scanAlignment,
            northAngle: northAngle,
            planRotation: planRotation
        )
    }
}

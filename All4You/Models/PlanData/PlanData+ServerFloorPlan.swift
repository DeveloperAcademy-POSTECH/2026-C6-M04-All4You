// 변환 서버의 도면 JSON(픽셀)을 앱 도면(PlanData, m)으로 바꾸기
// 서버가 주지 않는 벽 두께·높이, 문·창문 높이, 가구 높이는 기본값으로 채운다

import Foundation

extension PlanData {
    /// 변환 서버의 JSON을 도면으로 바꾼다. 좌표가 없는 미리보기 형식이면 에러
    init(serverJSON data: Data) throws {
        self.init(server: try ServerFloorPlan.decode(data))
    }

    init(server: ServerFloorPlan) {
        let scale = server.metersPerPixel
        var unnamedCount = 0

        self.init(
            version: 1,
            vertices: server.vertices.map { Vertex(id: $0.id, x: $0.x * scale, y: $0.y * scale) },
            walls: server.walls.map {
                Wall(
                    id: $0.id,
                    startVertex: $0.startVertex,
                    endVertex: $0.endVertex,
                    thickness: ServerDefault.wallThickness,
                    height: ServerDefault.wallHeight,
                    isVirtual: false
                )
            },
            doorWindows: server.openings.map { opening in
                // 서버는 모르는 종류를 줄 수 있어, 문·창문이 아니면 문짝 없는 출입구로 본다
                let kind = DoorWindowKind(rawValue: opening.kind) ?? .passage
                let isWindow = kind == .window
                return DoorWindow(
                    id: opening.id,
                    wallId: opening.wallId,
                    kind: kind,
                    // 서버는 시작 위치를 주고 앱은 중심 위치로 저장한다
                    centerAlongWall: (opening.offset + opening.width / 2) * scale,
                    width: opening.width * scale,
                    sillHeight: isWindow ? ServerDefault.windowSillHeight : 0,
                    height: isWindow ? ServerDefault.windowHeight : ServerDefault.doorHeight
                )
            },
            wallFixtures: [],
            rooms: server.rooms.map { room in
                var name = room.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if name.isEmpty {
                    unnamedCount += 1
                    name = "\(ServerDefault.unnamedRoom) \(unnamedCount)"
                }
                let label = room.labelPosition ?? []
                return Room(
                    id: room.id,
                    name: name,
                    boundary: room.boundary.map { RoomEdge(wallId: $0.wallId, forward: $0.forward) },
                    labelX: (label.first ?? 0) * scale,
                    labelY: (label.dropFirst().first ?? 0) * scale
                )
            },
            markers: [],
            furniture: (server.furniture ?? []).compactMap { Furniture(server: $0, scale: scale) }
        )
    }
}

extension Furniture {
    /// 서버 가구 상자를 돌리지 않은 사각형 가구로. 상자 값이 네 개가 아니거나 크기가 0이면 nil
    fileprivate init?(server: ServerFloorPlan.Furniture, scale: Double) {
        guard server.bbox.count == 4 else { return nil }
        let topLeft = SIMD2(min(server.bbox[0], server.bbox[2]), min(server.bbox[1], server.bbox[3])) * scale
        let bottomRight = SIMD2(max(server.bbox[0], server.bbox[2]), max(server.bbox[1], server.bbox[3])) * scale
        let size = bottomRight - topLeft
        guard size.x > 0, size.y > 0 else { return nil }
        let label = server.label?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.init(
            id: server.id,
            label: label.isEmpty ? ServerDefault.unnamedFurniture : label,
            category: nil,
            shape: .rectangle,
            center: (topLeft + bottomRight) / 2,
            width: size.x,
            depth: size.y,
            rotation: 0,
            height: ServerDefault.furnitureHeight,
            elevation: 0
        )
    }
}

extension ServerFloorPlan {
    /// 픽셀 하나가 몇 m인지. 서버가 축척을 주면 그 값, 아니면 가장 긴 변을 정해 둔 길이로 본다
    var metersPerPixel: Double {
        if let given = calibration?.metersPerPixel, given > 0 { return given }
        let xs = vertices.map(\.x)
        let ys = vertices.map(\.y)
        let longestSide = max((xs.max() ?? 0) - (xs.min() ?? 0), (ys.max() ?? 0) - (ys.min() ?? 0))
        guard longestSide > 0 else { return 1 }
        return ServerDefault.assumedLongestSide / longestSide
    }
}

/// 서버가 주지 않는 값의 기본값 (m)
private enum ServerDefault {
    // TEMP: 서버가 축척을 주지 않을 때 쓰는 임시값. 도면의 가장 긴 변을 10m로 본다 (예시 도면 3개 기준 약 0.0032~0.0039 m/px)
    // 사진 해상도가 달라도 도면 크기가 비슷하게 나오도록 고정 비율 대신 긴 변 길이로 정함 — 실제 축척 기준이 정해지면 바꿈
    static let assumedLongestSide = 10.0
    static let wallThickness = 0.15
    static let wallHeight = 2.4
    static let doorHeight = 2.0
    static let windowSillHeight = 0.9
    static let windowHeight = 1.2
    /// 이름이 빈 방에 붙이는 이름. 뒤에 1부터 번호를 붙인다
    static let unnamedRoom = "공간"
    /// 가구 자체 높이. 서버는 높이를 주지 않는다
    static let furnitureHeight = 0.75
    /// 이름이 빈 가구에 붙이는 이름
    static let unnamedFurniture = "가구"
}

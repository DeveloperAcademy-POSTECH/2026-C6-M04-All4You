// RoomPlan 스캔 결과(CapturedRoom·CapturedStructure)를 중간 형식(ScanSurface)으로 옮기기

import RoomPlan
import simd

extension PlanData {
    /// RoomPlan 스캔 결과를 도면으로. 합친 구조가 있으면 그것을, 없으면(구간 하나, 또는 합치기 실패) 가장 큰 구간 하나를 쓴다.
    /// 구간들은 같은 벽을 따로 스캔해 그대로 모으면 벽이 겹치고 방이 닫히지 않는다
    init(structure: CapturedStructure?, rooms: [CapturedRoom]) {
        if let structure {
            self.init(scanSurfaces: ScanSurface.surfaces(of: structure), sections: ScanSection.sections(of: structure))
        } else if let largest = rooms.max(by: { $0.walls.totalWidth < $1.walls.totalWidth }) {
            self.init(scanSurfaces: ScanSurface.surfaces(of: largest), sections: ScanSection.sections(of: largest))
        } else {
            self = .empty
        }
    }
}

private extension [CapturedRoom.Surface] {
    /// 벽 폭을 모두 더한 길이. 구간 크기를 비교할 때 쓴다
    var totalWidth: Float {
        reduce(0) { $0 + $1.dimensions.x }
    }
}

extension ScanSurface {
    /// 구간 하나를 스캔한 결과의 면들
    static func surfaces(of room: CapturedRoom) -> [ScanSurface] {
        surfaces(walls: room.walls, doors: room.doors, windows: room.windows, openings: room.openings, floors: room.floors)
    }

    /// 여러 구간을 합친 결과의 면들
    static func surfaces(of structure: CapturedStructure) -> [ScanSurface] {
        surfaces(walls: structure.walls, doors: structure.doors, windows: structure.windows, openings: structure.openings, floors: structure.floors)
    }

    private static func surfaces(
        walls: [CapturedRoom.Surface],
        doors: [CapturedRoom.Surface],
        windows: [CapturedRoom.Surface],
        openings: [CapturedRoom.Surface],
        floors: [CapturedRoom.Surface]
    ) -> [ScanSurface] {
        walls.map { ScanSurface($0, kind: .wall) }
            + doors.map { ScanSurface($0, kind: .door) }
            + windows.map { ScanSurface($0, kind: .window) }
            + openings.map { ScanSurface($0, kind: .opening) }
            + floors.map { ScanSurface($0, kind: .floor) }
    }

    private init(_ surface: CapturedRoom.Surface, kind: Kind) {
        let transform = surface.transform
        let position = transform.columns.3
        // 면의 로컬 x축이 폭 방향이다. 위아래 성분은 버리고 바닥면 방향만 쓴다
        let axis = SIMD2(Double(transform.columns.0.x), Double(transform.columns.0.z))
        let length = simd_length(axis)
        self.init(
            id: surface.identifier,
            kind: kind,
            center: SIMD3(Double(position.x), Double(position.y), Double(position.z)),
            widthAxis: length > 0 ? axis / length : SIMD2(1, 0),
            width: Double(surface.dimensions.x),
            height: Double(surface.dimensions.y),
            parentId: surface.parentIdentifier
        )
    }
}

extension ScanSection {
    /// 구간 하나를 스캔한 결과의 방 종류들
    static func sections(of room: CapturedRoom) -> [ScanSection] {
        room.sections.map(ScanSection.init)
    }

    /// 여러 구간을 합친 결과의 방 종류들
    static func sections(of structure: CapturedStructure) -> [ScanSection] {
        structure.sections.map(ScanSection.init)
    }

    private init(_ section: CapturedRoom.Section) {
        let center = section.center
        self.init(name: Self.name(of: section.label), center: SIMD3(Double(center.x), Double(center.y), Double(center.z)))
    }

    /// RoomPlan 방 종류를 화면에 보일 이름으로
    private static func name(of label: CapturedRoom.Section.Label) -> String? {
        switch label {
        case .bedroom: "침실"
        case .bathroom: "욕실"
        case .diningRoom: "식당"
        case .kitchen: "주방"
        case .livingRoom: "거실"
        default: nil
        }
    }
}

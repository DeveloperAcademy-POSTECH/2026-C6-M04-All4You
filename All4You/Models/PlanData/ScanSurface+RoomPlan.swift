// RoomPlan 스캔 결과(CapturedRoom·CapturedStructure)를 중간 형식(ScanSurface)으로 옮기기

import RoomPlan
import simd

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

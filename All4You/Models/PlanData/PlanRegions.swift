// 도면의 영역 계산. 벽으로 닫힌 칸과 스캔한 바닥을 한 목록으로 모은다. 저장하지 않고 그때그때 계산한다
//
// 용어
// - 공간 라벨(Room): 도면에 "거실" 같은 이름을 붙인 표시. 이름과 자리(점)만 갖고, 방의 모양은 저장하지 않는다
// - 닫힌 칸: 벽으로 빈틈없이 둘러싸인 공간. 벽 연결에서 계산한다 (RoomTracer.faceLoops)
// - 바닥: 공간 스캔이 알려 준 바닥 모양 (PlanData.floors)
// - 영역: 닫힌 칸과 바닥을 합쳐 부르는 말
//
// 공간 라벨의 영역은 라벨 자리를 품은 영역이다. 닫힌 칸이 먼저이고, 그 자리를 품은 닫힌 칸이 없으면 바닥을 쓴다.
// 한 영역 안에 라벨이 여럿이면 점에서 가장 가까운 라벨이 그 점의 라벨이다 (사진을 장소에 자동으로 놓을 때 쓴다)

import Foundation

/// 도면의 영역들. 화면 상태가 아니라 계산용 값이다 (WallLine과 같은 성격)
struct PlanRegions {
    /// 영역 하나
    struct Region: Equatable {
        /// 영역을 한 바퀴 도는 꼭짓점 (도면 좌표, m)
        let polygon: [SIMD2<Double>]
        /// 넓이 (㎡). 항상 양수
        let area: Double
        /// 벽으로 닫힌 칸이면 true, 스캔한 바닥이면 false
        let isClosedCell: Bool
    }

    /// 벽으로 닫힌 칸들(넓이 > eps) 다음에 바닥들
    let regions: [Region]

    init(plan: PlanData) {
        var found: [Region] = []
        for loop in plan.faceLoops() ?? [] where loop.area > WallMoveRules.eps {
            found.append(Region(polygon: loop.points, area: loop.area, isClosedCell: true))
        }
        for floor in plan.floors ?? [] where floor.corners.count >= 3 {
            let polygon = floor.corners.map { SIMD2($0.x, $0.y) }
            let area = abs(PlanData.signedArea(polygon))
            guard area > WallMoveRules.eps else { continue }
            found.append(Region(polygon: polygon, area: area, isClosedCell: false))
        }
        regions = found
    }

    /// 점을 품은 영역. 닫힌 칸이 있으면 가장 작은 닫힌 칸, 없으면 가장 작은 바닥. 어느 영역에도 없으면 nil
    func region(containing point: SIMD2<Double>) -> Region? {
        let holders = regions.filter { PlanData.polygon($0.polygon, contains: point) }
        let cells = holders.filter(\.isClosedCell)
        return (cells.isEmpty ? holders : cells).min { $0.area < $1.area }
    }
}

extension PlanData {
    /// 지금 도면의 영역들. 반복문 안에서 여러 번 부르지 말고 한 번 만들어 넘긴다 (벽 수에 비례해 계산한다)
    var regions: PlanRegions { PlanRegions(plan: self) }

    /// 라벨의 영역. 라벨 자리를 품은 영역. 없으면 nil (영역 없는 라벨)
    func region(of room: Room, in regions: PlanRegions) -> PlanRegions.Region? {
        guard room.labelX.isFinite, room.labelY.isFinite else { return nil }
        return regions.region(containing: SIMD2(room.labelX, room.labelY))
    }

    /// 점이 든 영역 안의 라벨 가운데 가장 가까운 것. 영역이 없거나 그 안에 라벨이 없으면 nil
    func room(containing point: SIMD2<Double>) -> Room? {
        room(containing: point, in: regions)
    }

    /// room(containing:)과 같다. 여러 점을 이어서 찾을 때 영역을 한 번만 만들어 넘긴다
    func room(containing point: SIMD2<Double>, in regions: PlanRegions) -> Room? {
        guard let region = regions.region(containing: point) else { return nil }
        func squaredDistance(_ room: Room) -> Double {
            let dx = room.labelX - point.x
            let dy = room.labelY - point.y
            return dx * dx + dy * dy
        }
        return rooms
            .filter { self.region(of: $0, in: regions) == region }
            .min { squaredDistance($0) < squaredDistance($1) }
    }
}

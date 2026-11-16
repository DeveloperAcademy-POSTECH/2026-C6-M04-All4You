// 도면의 영역 계산. 벽으로 닫힌 칸과 스캔한 바닥을 한 목록으로 모은다. 저장하지 않고 그때그때 계산한다
//
// 공간 라벨은 이름과 자리(점)만 갖고, 그 자리를 품은 영역이 라벨의 영역이다.
// 영역은 벽으로 닫힌 칸이 먼저이고, 그 자리를 품은 닫힌 칸이 없으면 바닥을 쓴다

import Foundation

/// 도면의 영역들. 화면 상태가 아니라 계산용 값이다 (WallLine과 같은 성격)
struct PlanRegions {
    /// 영역 하나
    struct Region {
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
            found.append(Region(polygon: plan.points(of: loop.edges), area: loop.area, isClosedCell: true))
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
}

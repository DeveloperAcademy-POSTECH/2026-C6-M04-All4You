// 점이 다각형 안인지 보는 계산과, 스탬프가 바닥에서 차지하는 자리(footprint)

import Foundation

extension PlanData {
    /// 다각형 안에 점이 있는지. 점에서 오른쪽으로 그은 선이 변을 홀수 번 지나면 안이다
    static func polygon(_ points: [SIMD2<Double>], contains p: SIMD2<Double>) -> Bool {
        guard points.count >= 3 else { return false }
        var isInside = false
        var previous = points[points.count - 1]
        for current in points {
            let crossesRow = (current.y > p.y) != (previous.y > p.y)
            if crossesRow {
                let crossX = current.x + (p.y - current.y) / (previous.y - current.y) * (previous.x - current.x)
                if p.x < crossX { isInside.toggle() }
            }
            previous = current
        }
        return isInside
    }
}

// 스탬프가 바닥에서 차지하는 자리
extension PlanMarker {
    /// 3D 모델 크기(m)를 위에서 본 자리. 가운데 선분(start → end)과, 그 선분에서 바깥 가장자리까지(radius).
    /// 누운 사람은 발끝 → 머리끝 선분, 선 사람·발화지점은 점(원). 크기 배율을 곱한다
    var footprint: (start: SIMD2<Double>, end: SIMD2<Double>, radius: Double) {
        let size = drawScale
        guard kind == .person, lying == true else {
            return (position, position, Footprint.uprightRadius * size)
        }
        // 머리가 향하는 방향. yaw는 도면 위쪽 0°에서 시계 방향, 도면은 +y가 아래
        let radians = yaw * .pi / 180
        let headward = SIMD2(sin(radians), -cos(radians))
        return (
            position - headward * (Footprint.lyingToFeet * size),
            position + headward * (Footprint.lyingToHead * size),
            Footprint.lyingHalfWidth * size
        )
    }

    /// 3D 모델(FloorPlan3DBuilder)의 크기 (m). 모델을 바꾸면 함께 바꾼다
    private enum Footprint {
        /// 누운 사람: 표시 위치(몸통 가운데)에서 발끝까지, 머리끝까지, 몸 폭의 절반
        static let lyingToFeet = 0.6 * PlanMarker.personTokenScale
        static let lyingToHead = 0.88 * PlanMarker.personTokenScale
        static let lyingHalfWidth = 0.2 * PlanMarker.personTokenScale
        /// 선 사람·발화지점이 바닥에서 차지하는 원의 반지름
        static let uprightRadius = 0.2
    }
}

// 직접 그리기 스케치 위에 놓은 스탬프(SketchStamp)를 변환된 도면(PlanData)으로 옮기는 계산
// 스케치 점 → 보낸 이미지의 픽셀 → 도면 좌표(m)로 바꾼 뒤, 발화지점·피해자는 벽에서 떨어진 바닥에, 전기는 벽이나 바닥에 놓는다

import Foundation

/// 스케치 점을 도면 좌표(m)로 바꾸는 값. 이미지를 만들 때 쓴 영역·배율과 서버가 준 픽셀당 미터로 계산한다
struct SketchToPlan {
    /// 서버에 보낸 이미지가 스케치의 어디부터인지 (이미지 왼쪽 위의 스케치 점)
    let imageOrigin: CGPoint
    /// 스케치 1pt가 이미지 몇 픽셀인지
    let pixelsPerPoint: Double
    /// 픽셀 하나가 몇 m인지 (ServerFloorPlan.metersPerPixel)
    let metersPerPixel: Double

    /// 스케치 점의 도면 좌표 (m)
    func plan(_ point: CGPoint) -> SIMD2<Double> {
        let pixelX = Double(point.x - imageOrigin.x) * pixelsPerPoint
        let pixelY = Double(point.y - imageOrigin.y) * pixelsPerPoint
        return SIMD2(pixelX, pixelY) * metersPerPixel
    }
}

extension PlanData {
    /// 벽에 닿는 자리에 놓은 스탬프를 벽에서 떨어진 자리로 당길 때 찾아보는 가장 먼 거리 (m)
    // TEMP: 실기기에서 스케치해 보고 정한다
    static let sketchStampMaxPull = 2.5
    /// 전기가 이 거리(m) 안에 벽(벽 표면 기준)이 있으면 벽에 붙이고, 아니면 바닥에 놓는다
    // TEMP: 실기기에서 스케치해 보고 정한다
    static let sketchOutletWallReach = 0.4

    /// 스케치 스탬프를 도면에 넣고, 넣지 못한 개수를 돌려준다. 못 넣은 것은 뺀다
    mutating func addSketchStamps(_ stamps: [SketchStamp], using transform: SketchToPlan) -> Int {
        var failed = 0
        for stamp in stamps {
            let point = transform.plan(stamp.position)
            let id = switch stamp.kind {
            case .ignitionPoint, .person: addMarkerNearest(stamp, to: point)
            case .outlet: addSketchOutlet(stamp, at: point)
            }
            guard let id else {
                failed += 1
                continue
            }
            if let note = stamp.kindNote { setKindNote(id: id, to: note) }
        }
        return failed
    }

    /// 전기: 가까운 벽이 있으면 벽에 붙이고(붙지 못하면 바닥으로), 없으면 바닥에 놓는다
    private mutating func addSketchOutlet(_ stamp: SketchStamp, at point: SIMD2<Double>) -> String? {
        if let wallId = nearestWallId(to: point, within: Self.sketchOutletWallReach),
           let id = addWallFixture(.outlet, wallId: wallId, at: point, height: Plan2DHit.outletHeight, electricalKind: stamp.electricalKind) {
            return id
        }
        return addMarkerNearest(stamp, to: point)
    }

    /// 점에서 벽 표면까지 reach(m) 안인 가장 가까운 벽
    private func nearestWallId(to point: SIMD2<Double>, within reach: Double) -> String? {
        walls
            .compactMap { wall -> (id: String, distance: Double)? in
                guard let line = line(of: wall) else { return nil }
                let distance = line.distance(to: point) - wall.thickness / 2
                return distance <= reach ? (wall.id, distance) : nil
            }
            .min { $0.distance < $1.distance }?
            .id
    }

    /// 바닥 스탬프를 그 자리에 놓고, 벽에 닿으면 가장 가까이 벽에 닿지 않는 자리에 놓는다. 스케치 변환은 자동 생성이라 이 규칙을 지킨다.
    /// sketchStampMaxPull 안에 그런 자리가 없으면 nil
    private mutating func addMarkerNearest(_ stamp: SketchStamp, to point: SIMD2<Double>) -> String? {
        let step = 0.1
        let anglesPerRing = 24
        var radius = 0.0
        while radius <= Self.sketchStampMaxPull {
            let count = radius == 0 ? 1 : anglesPerRing
            for index in 0..<count {
                let angle = Double(index) / Double(count) * 2 * .pi
                let candidate = point + SIMD2(cos(angle), sin(angle)) * radius
                let marker = makeMarker(stamp.kind, at: candidate, ignitionCause: stamp.ignitionCause, electricalKind: stamp.electricalKind)
                if isClearOfWalls(marker) {
                    markers.append(marker)
                    return marker.id
                }
            }
            radius += step
        }
        return nil
    }

    /// 스탬프가 바닥에서 차지하는 자리(footprint)가 어느 벽 두께와도 겹치지 않는지
    private func isClearOfWalls(_ marker: PlanMarker) -> Bool {
        let footprint = marker.footprint
        return !walls.contains { wall in
            guard let line = line(of: wall) else { return false }
            let gap = Self.distance(between: (footprint.start, footprint.end), and: (line.start, line.end))
            return gap < wall.thickness / 2 + footprint.radius
        }
    }

    /// 두 선분 사이 가장 짧은 거리 (m). 서로 가로지르면 0
    private static func distance(
        between a: (SIMD2<Double>, SIMD2<Double>),
        and b: (SIMD2<Double>, SIMD2<Double>)
    ) -> Double {
        func cross(_ o: SIMD2<Double>, _ p: SIMD2<Double>, _ q: SIMD2<Double>) -> Double {
            (p.x - o.x) * (q.y - o.y) - (p.y - o.y) * (q.x - o.x)
        }
        let crossesB = (cross(b.0, b.1, a.0) > 0) != (cross(b.0, b.1, a.1) > 0)
        let crossesA = (cross(a.0, a.1, b.0) > 0) != (cross(a.0, a.1, b.1) > 0)
        if crossesA && crossesB { return 0 }
        let lineA = WallLine(start: a.0, end: a.1)
        let lineB = WallLine(start: b.0, end: b.1)
        return min(lineA.distance(to: b.0), lineA.distance(to: b.1), lineB.distance(to: a.0), lineB.distance(to: a.1))
    }
}

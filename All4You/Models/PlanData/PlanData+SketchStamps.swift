// 직접 그리기 스케치 위에 놓은 스탬프(SketchStamp)를 변환된 도면(PlanData)으로 옮기는 계산
// 스케치 점 → 보낸 이미지의 픽셀 → 도면 좌표(m)로 바꾼 뒤, 발화지점·피해자는 방 안에, 전기는 벽이나 바닥에 놓는다

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
    /// 방 안이 아닌 자리에 놓은 스탬프를 안쪽으로 당길 때 찾아보는 가장 먼 거리 (m)
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

    /// 점에서 벽 표면까지 reach(m) 안인 가장 가까운 벽. 가상 경계선은 고르지 않는다
    private func nearestWallId(to point: SIMD2<Double>, within reach: Double) -> String? {
        walls
            .filter { !$0.isVirtual }
            .compactMap { wall -> (id: String, distance: Double)? in
                guard let line = line(of: wall) else { return nil }
                let distance = line.distance(to: point) - wall.thickness / 2
                return distance <= reach ? (wall.id, distance) : nil
            }
            .min { $0.distance < $1.distance }?
            .id
    }

    /// 바닥 스탬프를 그 자리에 놓고, 놓을 수 없으면(방 밖·벽에 닿음) 가장 가까이 놓을 수 있는 자리에 놓는다.
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
                if let id = addMarker(stamp.kind, at: candidate, ignitionCause: stamp.ignitionCause, electricalKind: stamp.electricalKind) {
                    return id
                }
            }
            radius += step
        }
        return nil
    }
}

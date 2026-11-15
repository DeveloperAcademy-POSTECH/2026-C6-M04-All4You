// 합치기 실패로 구간(CapturedRoom)을 따로 받았을 때, 모든 구간의 면·물체를 한 벌로 모으기
//
// 구간들은 같은 AR 세션의 같은 월드 좌표에서 스캔해 서로 겹친다. 그대로 모으면 같은 벽이 구간마다 따로 있어 벽이 겹치고 방이 닫히지 않으므로,
// 한 직선 위에서 겹치거나 맞닿는 벽은 하나로 합치고, 구간마다 따로 잡힌 같은 문·창문·물체는 하나만 남긴다

import Foundation
import simd

extension ScanSurface {
    /// 구간별 면을 한 벌로 모은다. 구간이 하나면 그대로 돌려준다
    static func combined(_ groups: [[ScanSurface]]) -> [ScanSurface] {
        guard groups.count > 1 else { return groups.first ?? [] }
        let all = groups.flatMap { $0 }
        let (walls, wallIdMap) = mergedWalls(all.filter { $0.kind == .wall })
        // 문·창문·개구부: 붙은 벽을 합친 벽으로 잇고, 구간마다 따로 잡힌 같은 것은 하나만 남긴다
        var openings: [ScanSurface] = []
        for surface in all where [.door, .window, .opening].contains(surface.kind) {
            let parent = surface.parentId.map { wallIdMap[$0] ?? $0 }
            let candidate = surface.withParent(parent)
            let isDuplicate = openings.contains { kept in
                kept.kind == candidate.kind && kept.parentId == candidate.parentId
                    && simd_distance(kept.center, candidate.center) < CombineRule.sameOpeningDistance
            }
            if !isDuplicate { openings.append(candidate) }
        }
        return walls + openings + all.filter { $0.kind == .floor }
    }

    /// 붙은 벽만 바꾼 복사본
    private func withParent(_ parent: UUID?) -> ScanSurface {
        ScanSurface(id: id, kind: kind, center: center, widthAxis: widthAxis, width: width, height: height, parentId: parent, corners: corners)
    }

    /// 한 직선 위에서 겹치거나 맞닿는 벽을 하나로 합친다. 돌려주는 값: 합친 벽 목록, 합쳐져 사라진 벽 id → 남은 벽 id
    private static func mergedWalls(_ walls: [ScanSurface]) -> (walls: [ScanSurface], idMap: [UUID: UUID]) {
        var result = walls
        var idMap: [UUID: UUID] = [:]
        var didMerge = true
        while didMerge {
            didMerge = false
            search: for i in result.indices {
                for j in result.indices where j > i {
                    guard let merged = merge(result[i], result[j]) else { continue }
                    // 합친 벽은 둘 중 더 긴 쪽의 id를 쓴다 (그 벽에 붙은 문·창문은 그대로)
                    let kept = result[i].width >= result[j].width ? result[i] : result[j]
                    let dropped = result[i].width >= result[j].width ? result[j] : result[i]
                    for (key, value) in idMap where value == dropped.id { idMap[key] = kept.id }
                    idMap[dropped.id] = kept.id
                    result[i] = merged
                    result.remove(at: j)
                    didMerge = true
                    break search
                }
            }
        }
        return (result, idMap)
    }

    /// 두 벽이 같은 직선 위에서 겹치거나 맞닿으면 합친 벽, 아니면 nil
    private static func merge(_ first: ScanSurface, _ second: ScanSurface) -> ScanSurface? {
        let longer = first.width >= second.width ? first : second
        let axis = longer.widthAxis
        let normal = SIMD2(-axis.y, axis.x)
        // 방향 차이: 축이 거의 나란해야 한다 (반대 방향도 같은 직선)
        let other = first.width >= second.width ? second : first
        guard abs(simd_dot(axis, other.widthAxis)) >= cos(CombineRule.angleTolerance) else { return nil }
        let origin = SIMD2(longer.center.x, longer.center.z)
        // 직선에서의 수직 거리: 두 벽의 가운데가 긴 벽의 직선에서 얼마나 떨어졌나
        let otherCenter = SIMD2(other.center.x, other.center.z)
        let offset = simd_dot(otherCenter - origin, normal)
        guard abs(offset) <= CombineRule.lineTolerance else { return nil }
        // 직선 위 구간 (긴 벽 가운데가 0)
        let longerRange = -longer.width / 2 ... longer.width / 2
        let otherT = simd_dot(otherCenter - origin, axis)
        let otherRange = otherT - other.width / 2 ... otherT + other.width / 2
        guard otherRange.lowerBound <= longerRange.upperBound + CombineRule.touchGap,
              longerRange.lowerBound <= otherRange.upperBound + CombineRule.touchGap else { return nil }
        let low = min(longerRange.lowerBound, otherRange.lowerBound)
        let high = max(longerRange.upperBound, otherRange.upperBound)
        // 직선은 두 벽의 어긋남을 길이로 가중해 나눈다 (긴 벽 쪽에 가깝게)
        let shift = offset * other.width / (longer.width + other.width)
        let center2D = origin + axis * ((low + high) / 2) + normal * shift
        // 높이: 두 벽이 덮는 위·아래 끝의 합
        let bottom = min(longer.center.y - longer.height / 2, other.center.y - other.height / 2)
        let top = max(longer.center.y + longer.height / 2, other.center.y + other.height / 2)
        return ScanSurface(
            id: longer.id, kind: .wall,
            center: SIMD3(center2D.x, (bottom + top) / 2, center2D.y),
            widthAxis: axis, width: high - low, height: top - bottom,
            parentId: nil, corners: []
        )
    }
}

extension ScanObject {
    /// 구간별 물체를 한 벌로 모은다. 구간마다 따로 잡힌 같은 물체(같은 종류, 가운데가 가까움)는 하나만 남긴다
    static func combined(_ groups: [[ScanObject]]) -> [ScanObject] {
        guard groups.count > 1 else { return groups.first ?? [] }
        var result: [ScanObject] = []
        for object in groups.flatMap({ $0 }) {
            let isDuplicate = result.contains { kept in
                kept.category == object.category && simd_distance(kept.center, object.center) < CombineRule.sameObjectDistance
            }
            if !isDuplicate { result.append(object) }
        }
        return result
    }
}

/// 구간 합치기에 쓰는 값
private enum CombineRule {
    /// 두 벽의 방향이 이 각도 안이면 같은 직선으로 본다 (5°)
    static let angleTolerance = 5 * Double.pi / 180
    /// 같은 직선으로 보는 수직 거리 (m). 구간마다 위치 복원이 달라 같은 벽이 20cm쯤 어긋나 잡히기도 한다 (보관된 원본으로 확인)
    static let lineTolerance = 0.25
    /// 두 벽 사이가 이만큼 이하로 벌어져 있으면 맞닿은 것으로 본다 (m)
    static let touchGap = 0.1
    /// 구간마다 따로 잡힌 같은 문·창문으로 보는 가운데 거리 (m)
    static let sameOpeningDistance = 0.3
    /// 구간마다 따로 잡힌 같은 물체로 보는 가운데 거리 (m)
    static let sameObjectDistance = 0.3
}

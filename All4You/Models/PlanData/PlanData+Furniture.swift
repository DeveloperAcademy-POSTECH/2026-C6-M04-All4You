// 2D에서 가구를 고르고 옮기고 돌리고 지우는 계산.
// 옮기거나 돌려서 벽과 더 겹치게 되면 바꾸지 않는다. 스캔한 가구는 처음부터 벽에 조금 걸쳐 있을 수 있어서, 겹침을 0으로 막지 않고 늘어나는 것만 막는다

import Foundation

extension PlanData {
    /// 도면 점 point 아래의 가구. 겹치면 나중에 그린(위에 보이는) 것
    func furniture(at point: SIMD2<Double>) -> Furniture? {
        furniture?.last { $0.contains(point) }
    }

    /// 가구 가운데를 도면 점 point로 옮긴다
    mutating func moveFurniture(id: String, to point: SIMD2<Double>) {
        updateFurniture(id: id) { $0.center = point }
    }

    /// 가구 방향을 rotation(라디안, 도면에서 시계 방향 +)으로 바꾼다
    mutating func rotateFurniture(id: String, rotation: Double) {
        updateFurniture(id: id) { $0.rotation = rotation }
    }

    mutating func removeFurniture(id: String) {
        furniture?.removeAll { $0.id == id }
    }

    /// 가구 하나를 change대로 바꿔 보고, 벽과 겹침이 늘지 않을 때만 반영한다
    private mutating func updateFurniture(id: String, _ change: (inout Furniture) -> Void) {
        guard let index = furniture?.firstIndex(where: { $0.id == id }), let current = furniture?[index] else { return }
        var changed = current
        change(&changed)
        guard wallOverlap(of: changed) <= wallOverlap(of: current) else { return }
        furniture?[index] = changed
    }

    /// 가구와 벽이 겹친 정도. 벽 가운데 선을 일정 간격 점으로 나눠, 가구를 벽 두께 절반만큼 넓힌 안에 든 점 수를 센다. 가상 경계선은 보지 않는다
    private func wallOverlap(of furniture: Furniture) -> Int {
        var count = 0
        for wall in walls where !wall.isVirtual {
            guard let line = line(of: wall) else { continue }
            let steps = Int((line.length / FurnitureRule.overlapSampleStep).rounded(.up))
            for step in 0...steps {
                let point = line.point(along: line.length * Double(step) / Double(max(steps, 1)))
                if furniture.contains(point, margin: wall.thickness / 2) { count += 1 }
            }
        }
        return count
    }
}

/// 가구 편집에 쓰는 값 (m)
private enum FurnitureRule {
    /// 벽과 겹침을 셀 때 벽 가운데 선 위 점 간격
    static let overlapSampleStep = 0.02
}

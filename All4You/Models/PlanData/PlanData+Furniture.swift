// 2D에서 가구를 고르고 옮기고 돌리고 크기·이름을 바꾸고 지우는 계산.
// 옮기거나 돌리거나 크기를 바꿔서 벽과 더 겹치게 되면 바꾸지 않는다. 스캔한 가구는 처음부터 벽에 조금 걸쳐 있을 수 있어서, 겹침을 0으로 막지 않고 늘어나는 것만 막는다

import Foundation

extension PlanData {
    /// 도면 점 point 아래의 가구. 겹치면 나중에 그린(위에 보이는) 것
    func furniture(at point: SIMD2<Double>) -> Furniture? {
        furniture?.last { $0.contains(point) }
    }

    /// 바닥 위 point(도면 좌표, m)에 새 가구를 놓고 새 id를 돌려준다. 벽과 겹치는 자리면 놓지 않고 nil
    /// TEMP: 새 가구의 크기·높이·이름은 디자인 확인 전이라 임시 값 (0.8×0.8m 사각형, 높이 0.75m, "가구")
    mutating func addFurniture(at point: SIMD2<Double>) -> String? {
        let new = Furniture(
            id: UUID().uuidString,
            label: FurnitureRule.newLabel,
            category: nil,
            shape: .rectangle,
            center: point,
            width: FurnitureRule.newSize,
            depth: FurnitureRule.newSize,
            rotation: 0,
            height: FurnitureRule.newHeight,
            elevation: 0
        )
        guard wallOverlap(of: new) == 0 else { return nil }
        furniture = (furniture ?? []) + [new]
        return new.id
    }

    /// 가구 가운데를 도면 점 point로 옮긴다
    mutating func moveFurniture(id: String, to point: SIMD2<Double>) {
        updateFurniture(id: id) { $0.center = point }
    }

    /// 가구 방향을 rotation(라디안, 도면에서 시계 방향 +)으로 바꾼다
    mutating func rotateFurniture(id: String, rotation: Double) {
        updateFurniture(id: id) { $0.rotation = rotation }
    }

    /// 가구 가로·세로(m)를 바꾼다. 가운데는 그대로이고, 원형은 지름 하나라 width만 쓴다
    mutating func resizeFurniture(id: String, width: Double, depth: Double) {
        updateFurniture(id: id) { furniture in
            furniture.width = max(width, Furniture.minSize)
            furniture.depth = furniture.shape == .circle ? furniture.width : max(depth, Furniture.minSize)
        }
    }

    /// 가구 이름을 바꾼다. 앞뒤 빈칸을 빼고 비어 있으면 바꾸지 않는다
    mutating func renameFurniture(id: String, to label: String) {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        updateFurniture(id: id) { $0.label = trimmed }
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
    /// 새로 놓는 가구의 가로·세로와 높이
    static let newSize = 0.8
    static let newHeight = 0.75
    static let newLabel = "가구"
}

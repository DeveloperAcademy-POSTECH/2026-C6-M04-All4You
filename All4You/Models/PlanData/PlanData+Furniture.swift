// 2D에서 가구를 고르고 옮기고 돌리고 크기·이름을 바꾸고 지우는 계산. 가구는 어디든 놓을 수 있다 (벽과 겹치거나 칸 밖이어도)

import Foundation

extension PlanData {
    /// 도면 점 point 아래의 가구. 겹치면 나중에 그린(위에 보이는) 것
    func furniture(at point: SIMD2<Double>) -> Furniture? {
        furniture?.last { $0.contains(point) }
    }

    /// 바닥 위 point(도면 좌표, m)에 새 가구를 놓고 새 id를 돌려준다. 어디든 놓을 수 있다
    /// TEMP: 새 가구의 크기·높이·이름은 디자인 확인 전이라 임시 값 (0.8×0.8m 사각형, 높이 0.75m, "가구")
    mutating func addFurniture(at point: SIMD2<Double>) -> String {
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
        furniture = (furniture ?? []) + [new]
        reseatMarkers()
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

    /// 가구를 바닥에서 elevation(m)만큼 띄운다. 0(바닥)부터 천장에 닿기 전까지(가구 높이를 더해서)로 맞춘다
    mutating func elevateFurniture(id: String, to elevation: Double) {
        guard let index = furniture?.firstIndex(where: { $0.id == id }), let item = furniture?[index] else { return }
        let limit = maxElevation(of: item)
        furniture?[index].elevation = min(max(elevation, 0), limit)
        reseatMarkers()
    }

    /// 가구를 띄울 수 있는 가장 높은 자리 (m). 천장(가장 높은 벽)에서 가구 높이를 뺀 만큼이고, 벽이 없으면 한계가 없다
    func maxElevation(of furniture: Furniture) -> Double {
        guard let ceiling = walls.map(\.height).max() else { return .infinity }
        return max(ceiling - furniture.height, 0)
    }

    /// 가구 이름을 바꾼다. 앞뒤 빈칸을 빼고 비어 있으면 바꾸지 않는다
    mutating func renameFurniture(id: String, to label: String) {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        updateFurniture(id: id) { $0.label = trimmed }
    }

    mutating func removeFurniture(id: String) {
        furniture?.removeAll { $0.id == id }
        reseatMarkers()
    }

    /// 가구 하나를 change대로 바꾼다
    private mutating func updateFurniture(id: String, _ change: (inout Furniture) -> Void) {
        guard let index = furniture?.firstIndex(where: { $0.id == id }) else { return }
        change(&furniture![index])
        reseatMarkers()
    }
}

/// 가구 편집에 쓰는 값 (m)
private enum FurnitureRule {
    /// 새로 놓는 가구의 가로·세로와 높이
    static let newSize = 0.8
    static let newHeight = 0.75
    static let newLabel = "가구"
}

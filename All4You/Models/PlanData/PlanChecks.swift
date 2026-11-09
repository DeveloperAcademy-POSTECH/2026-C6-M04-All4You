// 벽을 옮긴 결과 도면이 깨지지 않았는지 보는 검사. 벽끼리 겹치거나, 꼭짓점 없이 닿거나 가로지르면 깨진 도면이다
// 가로·세로 벽끼리만 본다. 비스듬한 벽은 이 검사에서 뺀다

extension PlanData {
    /// 벽 겹침·교차가 없으면 true
    var hasNoCrossingWalls: Bool {
        let eps = WallMoveRules.eps
        let pos = vertexPoints
        struct Segment { let id: String; let ends: Set<String>; let a: SIMD2<Double>; let b: SIMD2<Double>; let horizontal: Bool }
        var segments: [Segment] = []
        for wall in walls {
            guard let a = pos[wall.startVertex], let b = pos[wall.endVertex] else { return false }
            guard let axis = axis(of: wall, pos) else { continue }
            segments.append(Segment(id: wall.id, ends: [wall.startVertex, wall.endVertex], a: a, b: b, horizontal: axis == .horizontal))
        }
        for i in segments.indices {
            for j in segments.indices where j > i {
                let p = segments[i]
                let q = segments[j]
                if p.horizontal == q.horizontal {
                    // 같은 줄 위의 평행한 벽: 겹치거나, 꼭짓점을 함께 쓰지 않고 끝이 닿으면 깨짐
                    let across = p.horizontal ? 1 : 0
                    let along = p.horizontal ? 0 : 1
                    guard abs(p.a[across] - q.a[across]) < eps else { continue }
                    let low = max(min(p.a[along], p.b[along]), min(q.a[along], q.b[along]))
                    let high = min(max(p.a[along], p.b[along]), max(q.a[along], q.b[along]))
                    if high - low > eps { return false }
                    if high - low > -eps, p.ends.isDisjoint(with: q.ends) { return false }
                } else {
                    // 가로·세로 벽: 꼭짓점을 함께 쓰지 않고 닿거나 가로지르면 깨짐
                    let h = p.horizontal ? p : q
                    let v = p.horizontal ? q : p
                    let x = v.a.x
                    let y = h.a.y
                    let touches = x >= min(h.a.x, h.b.x) - eps && x <= max(h.a.x, h.b.x) + eps
                        && y >= min(v.a.y, v.b.y) - eps && y <= max(v.a.y, v.b.y) + eps
                    if touches, h.ends.isDisjoint(with: v.ends) { return false }
                }
            }
        }
        return true
    }
}

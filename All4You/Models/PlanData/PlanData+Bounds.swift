// 도면 전체가 차지하는 범위. 2D 화면 맞춤과 3D 가운데 맞춤이 함께 쓴다

extension PlanData {
    /// 꼭짓점을 모두 감싸는 사각형의 왼쪽 위(min)와 오른쪽 아래(max) (m). 꼭짓점이 없으면 둘 다 원점
    var bounds: (min: SIMD2<Double>, max: SIMD2<Double>) {
        let xs = vertices.map(\.x)
        let ys = vertices.map(\.y)
        return (SIMD2(xs.min() ?? 0, ys.min() ?? 0), SIMD2(xs.max() ?? 0, ys.max() ?? 0))
    }
}

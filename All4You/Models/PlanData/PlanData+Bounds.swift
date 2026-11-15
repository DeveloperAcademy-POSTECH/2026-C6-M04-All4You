// 도면 전체가 차지하는 범위. bounds는 3D 가운데 맞춤이, fitBounds는 2D 화면 맞춤이 쓴다

import simd

extension PlanData {
    /// 꼭짓점을 모두 감싸는 사각형의 왼쪽 위(min)와 오른쪽 아래(max) (m). 꼭짓점이 없으면 둘 다 원점
    var bounds: (min: SIMD2<Double>, max: SIMD2<Double>) {
        let xs = vertices.map(\.x)
        let ys = vertices.map(\.y)
        return (SIMD2(xs.min() ?? 0, ys.min() ?? 0), SIMD2(xs.max() ?? 0, ys.max() ?? 0))
    }

    /// 화면 맞춤에 쓰는 범위. 꼭짓점에 가구 모서리까지 더해, 벽 밖에 놓인 가구(덜 닫힌 스캔)도 처음 맞춘 화면에 모두 들어오게 한다.
    /// 3D 가운데 맞춤은 벽만 보는 bounds를 그대로 쓴다
    var fitBounds: (min: SIMD2<Double>, max: SIMD2<Double>) {
        let points = vertices.map { SIMD2($0.x, $0.y) } + (furniture ?? []).flatMap(\.corners)
        guard let first = points.first else { return bounds }
        return points.reduce((min: first, max: first)) { (min: simd_min($0.min, $1), max: simd_max($0.max, $1)) }
    }
}

// 벽 한 줄의 양 끝 좌표와, 그 좌표로 계산하는 값(길이·방향·벽 위의 점)
//
// 벽 길이·방향을 저장하지 않고 꼭짓점에서 계산한다. 계산을 여기 모아 두면
// 2D·3D 화면은 이 값만 쓰고, 저장 구조가 바뀌어도 이 파일만 고치면 된다.
// 저장하는 데이터가 아니라 계산용 값이라 ERD에는 없다

/// 벽 한 줄을 도면 좌표(m)의 선분으로 본 값
struct WallLine {
    let start: SIMD2<Double>
    let end: SIMD2<Double>

    /// 벽 길이 (m)
    var length: Double {
        let delta = end - start
        return (delta * delta).sum().squareRoot()
    }

    /// 시작 → 끝 방향의 길이 1짜리 벡터. 길이가 0인 벽은 오른쪽(+x)으로 본다
    var direction: SIMD2<Double> {
        length > 0 ? (end - start) / length : SIMD2(1, 0)
    }

    /// 시작 → 끝 방향을 바라볼 때 왼쪽 면이 향하는 길이 1짜리 벡터 (WallFace.left 쪽).
    /// 도면은 +y가 아래쪽이라 (x, y) 방향의 왼쪽은 (y, -x)다
    var leftNormal: SIMD2<Double> {
        SIMD2(direction.y, -direction.x)
    }

    /// 벽 시작점에서 벽을 따라 distance(m)만큼 간 점.
    /// 문·창문의 centerAlongWall, 콘센트의 positionAlongWall을 도면 좌표로 바꿀 때 쓴다
    func point(along distance: Double) -> SIMD2<Double> {
        start + direction * distance
    }
}

// 도면에서 id로 찾기
extension PlanData {
    func vertex(id: String) -> Vertex? {
        vertices.first { $0.id == id }
    }

    func wall(id: String) -> Wall? {
        walls.first { $0.id == id }
    }

    /// 벽의 두 꼭짓점을 찾아 선분으로 만든다. 꼭짓점이 없으면 nil
    func line(of wall: Wall) -> WallLine? {
        guard let start = vertex(id: wall.startVertex),
              let end = vertex(id: wall.endVertex) else { return nil }
        return WallLine(start: SIMD2(start.x, start.y), end: SIMD2(end.x, end.y))
    }
}

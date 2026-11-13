// 도면 위에 그리는 치수선과 면적 글자를 계산한다. 화면(2D·3D·추후 메인·Export)은 이 선과 글자만 받아 그린다.
// 건축 도면처럼 치수선으로 어떤 것의 크기인지 보이게 한다:
// 벽은 벽 바깥쪽에 나란히 긋는 길이 선(바깥 줄), 창문·문은 벽 바로 옆에 폭을 재는 선(안쪽 줄),
// 가구는 윗면 두 변 옆에 가로·세로 선과 가운데의 면적, 피해자는 몸 옆에 길이 선, 공간은 바닥 색칠과 면적이다.
// 공간 면적은 방 경계 벽의 가운데 선으로 잰 값이라 벽 두께만큼 어림한 값이다

import Foundation

/// 치수를 보여 줄 항목 종류. 화면의 필터가 이 종류를 켜고 끈다
enum DimensionKind: CaseIterable, Hashable {
    case room
    case wall
    case opening
    case furniture
    case victim
}

/// 치수 보기 설정. 기본은 꺼져 있고, 켜면 고른 종류만 보인다
struct DimensionDisplay: Equatable {
    /// 치수를 보여 줄지
    var isShown = false
    /// 보여 줄 종류. 처음 켜면 모두 보인다
    var kinds = Set(DimensionKind.allCases)
}

/// 치수선 하나. 재는 대상 옆에 나란히 그은 선(start → end)과, 그 끝에서 대상으로 뻗는 보조선, 가운데 글자
struct DimensionLine: Identifiable, Equatable {
    /// 종류와 대상 id로 만든 값
    let id: String
    let kind: DimensionKind
    /// 치수선 양 끝 (도면 좌표, m)
    let start: SIMD2<Double>
    let end: SIMD2<Double>
    /// 보조선이 닿는 대상 위 자리. 각각 start·end에서 이 점으로 보조선을 긋는다
    let anchorStart: SIMD2<Double>
    let anchorEnd: SIMD2<Double>
    /// 선 가운데에 보일 글자 (예: "3.5m", "0.9×2m")
    let text: String
    /// 3D에서 선을 놓을 바닥에서 높이 (m)
    let height: Double
}

/// 면적 글자 하나. 공간은 바닥을 옅게 색칠할 다각형도 함께 준다
struct DimensionArea: Identifiable, Equatable {
    let id: String
    let kind: DimensionKind
    /// 화면에 보일 글자 (예: "12.4㎡")
    let text: String
    /// 글자를 놓을 도면 좌표 (m)
    let point: SIMD2<Double>
    /// 3D에서 글자를 놓을 바닥에서 높이 (m)
    let height: Double
    /// 이 자리에 이름 캡슐이 있으면 그 캡슐 아래로 내려 놓을 종류. 없으면 nil
    let below: DimensionCapsule?
    /// 색칠할 영역의 꼭짓점들 (도면 좌표). 색칠하지 않으면 빈 배열
    let polygon: [SIMD2<Double>]
}

/// 면적 글자를 아래로 내릴 때 피할 이름 캡슐 종류
enum DimensionCapsule {
    case room
    case furniture
}

/// 치수선들과 면적 글자들
struct DimensionMarks: Equatable {
    var lines: [DimensionLine] = []
    var areas: [DimensionArea] = []
}

extension PlanData {
    /// kinds에 든 종류의 치수선·면적 글자들. 가상 경계선과 너무 짧은 벽은 뺀다
    func dimensionMarks(kinds: Set<DimensionKind>) -> DimensionMarks {
        var marks = DimensionMarks()
        if kinds.contains(.room) { marks.areas += roomAreas() }
        if kinds.contains(.wall) { marks.lines += wallLines() }
        if kinds.contains(.opening) { marks.lines += openingLines() }
        if kinds.contains(.furniture) {
            marks.lines += furnitureLines()
            marks.areas += furnitureAreas()
        }
        if kinds.contains(.victim) { marks.lines += victimLines() }
        return marks
    }

    /// 방마다 바닥 면적과 색칠할 영역. 글자는 이름 캡슐 바로 아래에 놓는다
    private func roomAreas() -> [DimensionArea] {
        rooms.compactMap { room in
            let points = polygon(of: room)
            let area = abs(Self.signedArea(points))
            guard area > WallMoveRules.eps else { return nil }
            return DimensionArea(
                id: "room/\(room.id)", kind: .room, text: Self.areaText(area),
                point: SIMD2(room.labelX, room.labelY), height: DimensionRule.roomHeight, below: .room, polygon: points
            )
        }
    }

    /// 벽마다 길이 선. 벽의 바깥쪽(방이 없는 쪽)에 나란히 긋는다
    private func wallLines() -> [DimensionLine] {
        walls.compactMap { wall in
            guard !wall.isVirtual, let line = line(of: wall), line.length >= DimensionRule.minimumWallLength else { return nil }
            let side = outwardNormal(of: wall, line: line)
            let face = line.leftNormal * (wall.thickness / 2) * side.sign
            return DimensionLine(
                id: "wall/\(wall.id)", kind: .wall,
                start: line.start + side.vector * (wall.thickness / 2 + DimensionRule.wallTier),
                end: line.end + side.vector * (wall.thickness / 2 + DimensionRule.wallTier),
                anchorStart: line.start + face, anchorEnd: line.end + face,
                text: Self.lengthText(line.length), height: DimensionRule.floorLineHeight
            )
        }
    }

    /// 창문·문마다 폭을 재는 선. 벽 바로 옆(벽 길이 선보다 안쪽 줄)에 긋는다
    private func openingLines() -> [DimensionLine] {
        doorWindows.compactMap { opening in
            guard let wall = wall(id: opening.wallId), !wall.isVirtual, let line = line(of: wall) else { return nil }
            let side = outwardNormal(of: wall, line: line)
            let face = side.vector * (wall.thickness / 2)
            let from = line.point(along: opening.centerAlongWall - opening.width / 2)
            let to = line.point(along: opening.centerAlongWall + opening.width / 2)
            return DimensionLine(
                id: "opening/\(opening.id)", kind: .opening,
                start: from + side.vector * (wall.thickness / 2 + DimensionRule.openingTier),
                end: to + side.vector * (wall.thickness / 2 + DimensionRule.openingTier),
                anchorStart: from + face, anchorEnd: to + face,
                text: "\(Self.numberText(opening.width))×\(Self.numberText(opening.height))m",
                height: DimensionRule.floorLineHeight
            )
        }
    }

    /// 가구마다 가로·세로 선. 윗면 한 변(가로)과 이웃한 변(세로) 바깥에 긋는다. 원형은 지름 하나
    private func furnitureLines() -> [DimensionLine] {
        (furniture ?? []).flatMap { item -> [DimensionLine] in
            let across = SIMD2(cos(item.rotation), sin(item.rotation))
            let along = SIMD2(-sin(item.rotation), cos(item.rotation))
            let height = item.elevation + item.height + DimensionRule.furnitureLineLift
            switch item.shape {
            case .rectangle:
                let widthFrom = item.center - across * (item.width / 2) + along * (item.depth / 2)
                let widthTo = item.center + across * (item.width / 2) + along * (item.depth / 2)
                let depthFrom = item.center + across * (item.width / 2) - along * (item.depth / 2)
                let depthTo = item.center + across * (item.width / 2) + along * (item.depth / 2)
                return [
                    DimensionLine(
                        id: "furniture/\(item.id)/width", kind: .furniture,
                        start: widthFrom + along * DimensionRule.furnitureGap, end: widthTo + along * DimensionRule.furnitureGap,
                        anchorStart: widthFrom, anchorEnd: widthTo, text: "\(Self.numberText(item.width))m", height: height
                    ),
                    DimensionLine(
                        id: "furniture/\(item.id)/depth", kind: .furniture,
                        start: depthFrom + across * DimensionRule.furnitureGap, end: depthTo + across * DimensionRule.furnitureGap,
                        anchorStart: depthFrom, anchorEnd: depthTo, text: "\(Self.numberText(item.depth))m", height: height
                    ),
                ]
            case .circle:
                let radius = item.width / 2
                let from = item.center - across * radius + along * radius
                let to = item.center + across * radius + along * radius
                return [DimensionLine(
                    id: "furniture/\(item.id)/width", kind: .furniture,
                    start: from + along * DimensionRule.furnitureGap, end: to + along * DimensionRule.furnitureGap,
                    anchorStart: from - along * radius, anchorEnd: to - along * radius,
                    text: "Ø\(Self.numberText(item.width))m", height: height
                )]
            }
        }
    }

    /// 가구마다 윗면 면적. 가구 가운데에, 이름 캡슐 아래로 놓는다
    private func furnitureAreas() -> [DimensionArea] {
        (furniture ?? []).map { item in
            let area = item.shape == .circle ? .pi * item.width * item.width / 4 : item.width * item.depth
            return DimensionArea(
                id: "furniture/\(item.id)/area", kind: .furniture, text: Self.areaText(area),
                point: item.center, height: item.elevation + item.height + DimensionRule.aboveFurniture, below: .furniture, polygon: []
            )
        }
    }

    /// 피해자마다 몸 옆에 길이 선. 글자는 가로×세로와 바닥에서 차지하는 면적 (3D 모델 크기를 위에서 본 자리)
    private func victimLines() -> [DimensionLine] {
        markers.compactMap { marker in
            guard marker.kind == .person else { return nil }
            let footprint = marker.footprint
            let delta = footprint.end - footprint.start
            let spine = (delta * delta).sum().squareRoot()
            let axis = spine > WallMoveRules.eps ? delta / spine : SIMD2(1, 0)
            let normal = SIMD2(-axis.y, axis.x)
            let length = spine + footprint.radius * 2
            let width = footprint.radius * 2
            // 가운데 선분 둘레의 길쭉한 알약 모양 넓이
            let area = spine * width + .pi * footprint.radius * footprint.radius
            let from = footprint.start - axis * footprint.radius + normal * footprint.radius
            let to = footprint.end + axis * footprint.radius + normal * footprint.radius
            return DimensionLine(
                id: "victim/\(marker.id)", kind: .victim,
                start: from + normal * DimensionRule.victimGap, end: to + normal * DimensionRule.victimGap,
                anchorStart: from, anchorEnd: to,
                text: "\(Self.numberText(length))×\(Self.numberText(width))m · \(Self.areaText(area))",
                height: DimensionRule.victimLineHeight
            )
        }
    }

    /// 벽에서 방이 없는 쪽을 가리키는 방향. 방이 한쪽에만 있으면 그 반대쪽, 양쪽이나 없으면 벽의 왼쪽.
    /// 방은 화면에서 시계 방향으로 도므로, 경계가 벽을 시작 → 끝으로 돌면 방은 벽의 오른쪽에 있다
    private func outwardNormal(of wall: Wall, line: WallLine) -> (vector: SIMD2<Double>, sign: Double) {
        let roomSides = Set(rooms.flatMap(\.boundary).filter { $0.wallId == wall.id }.map { $0.forward ? -1.0 : 1.0 })
        let sign = roomSides.count == 1 ? -roomSides.first! : 1.0
        return (line.leftNormal * sign, sign)
    }
}

// 글자 만들기
extension PlanData {
    /// 소수 둘째 자리까지, 끝의 0은 뗀 숫자 (0.90 → "0.9", 2.0 → "2")
    static func numberText(_ value: Double) -> String {
        let text = String(format: "%.2f", value)
        guard text.contains(".") else { return text }
        var trimmed = text
        while trimmed.hasSuffix("0") { trimmed.removeLast() }
        if trimmed.hasSuffix(".") { trimmed.removeLast() }
        return trimmed
    }

    static func lengthText(_ meters: Double) -> String {
        "\(numberText(meters))m"
    }

    /// 면적은 소수 첫째 자리까지 ("12.4㎡")
    static func areaText(_ squareMeters: Double) -> String {
        String(format: "%.1f㎡", squareMeters)
    }
}

/// 치수선을 놓는 값 (m)
private enum DimensionRule {
    /// 이보다 짧은 벽은 길이를 재지 않는다
    static let minimumWallLength = 0.3
    /// 벽 면에서 치수선까지. 창문·문 폭 선이 안쪽 줄, 벽 길이 선이 바깥 줄이다
    static let openingTier = 0.2
    static let wallTier = 0.6
    /// 가구 변에서 치수선까지
    static let furnitureGap = 0.2
    /// 피해자 몸에서 치수선까지
    static let victimGap = 0.15
    /// 3D에서 벽·창문·문 치수선을 놓는 바닥에서 높이. 바닥에 닿아 깜빡이지 않게 조금 띄운다
    static let floorLineHeight = 0.03
    /// 3D에서 가구 치수선을 윗면에서 띄우는 높이
    static let furnitureLineLift = 0.02
    /// 3D에서 가구 면적 글자를 윗면에서 띄우는 높이. 이름 캡슐과 같다
    static let aboveFurniture = 0.05
    /// 3D에서 공간 면적을 놓는 높이. 공간 이름 캡슐과 같다
    static let roomHeight = 1.5
    /// 3D에서 피해자 치수선을 놓는 높이 (누운 몸 위)
    static let victimLineHeight = 0.3
}

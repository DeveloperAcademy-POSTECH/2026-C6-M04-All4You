// 도면을 위에서 본 2D 그림. 벽·문·창문은 선으로, 스탬프는 아이콘으로, 공간 이름은 캡슐로 그린다
// 그리기만 한다. 누르기·끌기는 이 그림을 쓰는 화면이 붙인다

import SwiftUI

/// planData를 screen의 배율과 자리에 맞춰 그린다
struct Plan2DView: View {
    let planData: PlanData
    let screen: PlanScreen
    /// 고른 표시(주황 사각 테두리)를 그릴 스탬프
    var selection: PlanSelection? = nil

    /// 스탬프 아이콘 크기 (m). 누르기 판정도 이 크기를 쓴다
    static let stampSize = 0.4

    var body: some View {
        Canvas { context, _ in
            for wall in planData.walls where !wall.isVirtual {
                guard let line = planData.line(of: wall) else { continue }
                drawWall(wall, line: line, in: &context)
            }
        }
        .overlay(alignment: .topLeading) {
            stamps
        }
        .overlay(alignment: .topLeading) {
            roomLabels
        }
    }
}

// 벽과 문·창문
extension Plan2DView {
    /// 벽을 그리되 문·창문 자리는 비우고, 그 자리에 문·창문 기호를 그린다
    private func drawWall(_ wall: Wall, line: WallLine, in context: inout GraphicsContext) {
        let openings = planData.doorWindows
            .filter { $0.wallId == wall.id }
            .sorted { $0.centerAlongWall < $1.centerAlongWall }
        var wallPath = Path()
        // 벽 양 끝은 두께의 절반만큼 늘여 모서리에서 만나는 벽과 빈틈 없이 잇는다
        let cornerOverlap = wall.thickness / 2
        var solidStart = -cornerOverlap
        for opening in openings {
            let start = opening.centerAlongWall - opening.width / 2
            addSegment(line, from: solidStart, to: start, to: &wallPath)
            solidStart = opening.centerAlongWall + opening.width / 2
            drawOpening(opening, wall: wall, line: line, in: &context)
        }
        addSegment(line, from: solidStart, to: line.length + cornerOverlap, to: &wallPath)
        let width = max(screen.length(wall.thickness), Layout.minimumWallWidth)
        context.stroke(wallPath, with: .color(.gray900), style: StrokeStyle(lineWidth: width, lineCap: .butt))
    }

    /// 벽 시작점에서 from~to(m) 구간을 선으로 더한다
    private func addSegment(_ line: WallLine, from: Double, to: Double, to path: inout Path) {
        guard to > from else { return }
        path.move(to: screen.point(line.point(along: from)))
        path.addLine(to: screen.point(line.point(along: to)))
    }

    /// 문은 문짝과 열리는 호, 창문은 벽 두께 안의 두 줄. 개구부는 비워 둔다
    private func drawOpening(_ opening: DoorWindow, wall: Wall, line: WallLine, in context: inout GraphicsContext) {
        let start = line.point(along: opening.centerAlongWall - opening.width / 2)
        let end = line.point(along: opening.centerAlongWall + opening.width / 2)
        let style = StrokeStyle(lineWidth: Layout.openingLineWidth)
        var path = Path()
        switch opening.kind {
        case .door:
            // 문짝은 시작 쪽 끝을 축으로 벽의 왼쪽 면으로 열린 모양
            let leafEnd = start + line.leftNormal * opening.width
            path.move(to: screen.point(start))
            path.addLine(to: screen.point(leafEnd))
            let startAngle = Angle(radians: atan2(line.leftNormal.y, line.leftNormal.x))
            let endAngle = Angle(radians: atan2(line.direction.y, line.direction.x))
            path.addArc(center: screen.point(start), radius: screen.length(opening.width), startAngle: startAngle, endAngle: endAngle, clockwise: false)
        case .window:
            let offset = line.leftNormal * (wall.thickness / 4)
            for side in [offset, -offset] {
                path.move(to: screen.point(start + side))
                path.addLine(to: screen.point(end + side))
            }
        case .passage:
            return
        }
        context.stroke(path, with: .color(.gray600), style: style)
    }
}

// 스탬프와 공간 이름
extension Plan2DView {
    /// 사람·발화지점과 콘센트. 크기를 도면 길이로 정해 확대하면 함께 커진다
    private var stamps: some View {
        ZStack(alignment: .topLeading) {
            ForEach(planData.markers) { marker in
                stampIcon(marker.kind == .person ? EditTool.person.iconName : EditTool.ignitionPoint.iconName)
                    .overlay { selectionBorder(isSelected: selection == .marker(marker.id)) }
                    .rotationEffect(.degrees(marker.yaw))
                    .position(screen.point(marker.position))
            }
            ForEach(planData.wallFixtures) { fixture in
                if let point = planData.point(of: fixture) {
                    stampIcon(EditTool.outlet.iconName)
                        .overlay { selectionBorder(isSelected: selection == .wallFixture(fixture.id)) }
                        .position(screen.point(point))
                }
            }
        }
    }

    /// 아이콘을 스탬프 크기의 정사각형 안 가운데에 둔다. 테두리가 아이콘 모양과 상관없이 같은 크기가 되게
    private func stampIcon(_ systemName: String) -> some View {
        let size = screen.length(Self.stampSize)
        return Image(systemName: systemName)
            .font(.system(size: size))
            .foregroundStyle(.brand500)
            .frame(width: size, height: size)
    }

    /// 고른 스탬프 둘레의 주황 사각 테두리
    @ViewBuilder
    private func selectionBorder(isSelected: Bool) -> some View {
        if isSelected {
            Rectangle()
                .stroke(.brand500, lineWidth: Layout.selectionLineWidth)
                .padding(-Layout.selectionPadding)
        }
    }

    /// 공간 이름 캡슐. 글자는 확대해도 같은 크기다
    private var roomLabels: some View {
        ZStack(alignment: .topLeading) {
            ForEach(planData.rooms) { room in
                RoomLabelView(name: room.name)
                    .position(screen.point(SIMD2(room.labelX, room.labelY)))
            }
        }
    }
}

// 레이아웃 값
extension Plan2DView {
    private enum Layout {
        /// 벽이 아주 얇아도 이만큼(pt)은 보이게
        static let minimumWallWidth = 1.0
        static let openingLineWidth: CGFloat = 1
        /// 고른 테두리 두께와, 아이콘에서 테두리까지 (pt)
        static let selectionLineWidth: CGFloat = 1.5
        static let selectionPadding: CGFloat = 6
    }
}

#Preview {
    GeometryReader { proxy in
        Plan2DView(planData: DummyFloorPlan.planData, screen: PlanScreen(plan: DummyFloorPlan.planData, in: proxy.size, fill: 0.8))
    }
}

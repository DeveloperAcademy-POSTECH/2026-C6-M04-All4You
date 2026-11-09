// 도면을 위에서 본 2D 그림. 벽·문·창문은 선으로, 가구는 윗면 모양으로, 스탬프는 아이콘으로, 공간·가구 이름은 캡슐로 그린다
// 그리기만 한다. 누르기·끌기는 이 그림을 쓰는 화면이 붙인다 (공간 이름 캡슐만 roomLabelActions로 누르기·끌기를 알린다)

import SwiftUI

/// planData를 screen의 배율과 자리에 맞춰 그린다
struct Plan2DView: View {
    let planData: PlanData
    let screen: PlanScreen
    /// 고른 표시(주황 사각 테두리)를 그릴 스탬프
    var selection: PlanSelection? = nil
    /// 이름을 고치는 중이라 캡슐 대신 입력칸을 띄울 방 (Room.id). 이 방의 캡슐은 그리지 않는다
    var editingRoomId: String? = nil
    /// 고른 표시(주황 사각 테두리)를 그릴 공간 이름 캡슐 (Room.id)
    var selectedRoomId: String? = nil
    /// 함께 고른 벽들 (Wall.id). 일직선 줄 전체를 고르면 여러 개다
    var selectedWallIds: Set<String> = []
    /// 공간 이름 캡슐을 누르거나 끌 때 알릴 곳. nil이면 캡슐은 보기만 한다
    var roomLabelActions: RoomLabelActions? = nil
    /// 이름 캡슐을 그리지 않을 방들 (Room.id). 사건 메인에서 사진 핀 캡슐이 이름을 대신하는 방에 쓴다
    var hiddenLabelRoomIds: Set<String> = []

    /// 콘센트 아이콘 크기 (m). 누르기 판정도 이 크기를 쓴다
    static let stampSize = 0.4

    /// 사람·발화지점 아이콘 크기 (m). 3D 모델이 바닥에서 차지하는 자리의 긴 쪽 길이라, 2D와 3D 크기가 같다
    static func iconSize(of marker: PlanMarker) -> Double {
        let footprint = marker.footprint
        let delta = footprint.end - footprint.start
        return max((delta * delta).sum().squareRoot(), footprint.radius * 2)
    }
    /// 아이콘에서 고른 테두리까지 (pt). 손잡이도 이 테두리 모서리에 붙는다
    static let selectionPadding: CGFloat = 6

    var body: some View {
        Canvas { context, _ in
            // 가구를 먼저 그려 벽에 붙은 가구 가장자리가 벽 아래로 들어가게 한다
            for furniture in planData.furniture ?? [] {
                drawFurniture(furniture, in: &context)
            }
            for wall in planData.walls where !wall.isVirtual {
                guard let line = planData.line(of: wall) else { continue }
                drawWall(wall, line: line, in: &context)
            }
        }
        // 가구 이름 → 공간 이름 → 스탬프 순으로 깔아, 겹치면 뒤의 것이 위에 보이게 한다
        .overlay(alignment: .topLeading) {
            furnitureLabels
        }
        .overlay(alignment: .topLeading) {
            roomLabels
        }
        .overlay(alignment: .topLeading) {
            stamps
        }
    }
}

/// 공간 이름 캡슐 누르기·끌기를 받을 곳
struct RoomLabelActions {
    /// 캡슐을 눌렀다 (Room.id)
    let onTap: (String) -> Void
    /// 캡슐을 끄는 중이다 (Room.id, 끌기 시작부터 움직인 거리)
    let onDrag: (String, CGSize) -> Void
    /// 끌기에서 손을 뗐다
    let onDragEnded: () -> Void
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
        // 고른 벽은 문·창문 자리까지 한 줄 전체를 주황으로 그린다
        let isSelected = selection == .wall(wall.id) || selectedWallIds.contains(wall.id)
        context.stroke(wallPath, with: .color(isSelected ? .brand500 : .gray900), style: StrokeStyle(lineWidth: width, lineCap: .butt))
    }

    /// 벽 시작점에서 from~to(m) 구간을 선으로 더한다
    private func addSegment(_ line: WallLine, from: Double, to: Double, to path: inout Path) {
        guard to > from else { return }
        path.move(to: screen.point(line.point(along: from)))
        path.addLine(to: screen.point(line.point(along: to)))
    }

    /// 문은 문짝과 열리는 호, 창문은 벽 두께 안의 두 줄. 개구부는 비워 둔다.
    /// 고른 창문·문은 벽 두께만큼 옅은 주황 띠를 깔고 기호를 주황으로 그린다
    private func drawOpening(_ opening: DoorWindow, wall: Wall, line: WallLine, in context: inout GraphicsContext) {
        let start = line.point(along: opening.centerAlongWall - opening.width / 2)
        let end = line.point(along: opening.centerAlongWall + opening.width / 2)
        let isSelected = selection == .doorWindow(opening.id)
        if isSelected {
            var band = Path()
            band.move(to: screen.point(start))
            band.addLine(to: screen.point(end))
            let bandWidth = max(screen.length(wall.thickness), Layout.minimumWallWidth)
            context.stroke(band, with: .color(.brand500.opacity(Layout.selectedOpeningOpacity)), style: StrokeStyle(lineWidth: bandWidth))
        }
        let style = StrokeStyle(lineWidth: isSelected ? Layout.selectedOpeningLineWidth : Layout.openingLineWidth)
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
        context.stroke(path, with: .color(isSelected ? .brand500 : .gray600), style: style)
    }
}

// 가구
extension Plan2DView {
    /// 가구 윗면을 옅은 회색으로 채우고 테두리를 긋는다. 바닥에서 띄운 가구(벽 수납장 등)는 테두리를 점선으로
    private func drawFurniture(_ furniture: Furniture, in context: inout GraphicsContext) {
        let path: Path
        switch furniture.shape {
        case .rectangle:
            path = Path { shape in
                shape.addLines(furniture.corners.map(screen.point))
                shape.closeSubpath()
            }
        case .circle:
            let center = screen.point(furniture.center)
            let radius = screen.length(furniture.width / 2)
            path = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        }
        let isFloating = furniture.elevation > Layout.floatingElevation
        context.fill(path, with: .color(.gray100))
        context.stroke(path, with: .color(.gray500), style: StrokeStyle(lineWidth: Layout.furnitureLineWidth, dash: isFloating ? Layout.floatingDash : []))
    }

    /// 가구 가운데의 이름 캡슐. 가구를 돌려도 글자는 바로 선다
    private var furnitureLabels: some View {
        ZStack(alignment: .topLeading) {
            ForEach(planData.furniture ?? []) { furniture in
                FurnitureLabelView(label: furniture.label)
                    .position(screen.point(furniture.center))
            }
        }
        .allowsHitTesting(false)
    }
}

// 스탬프와 공간 이름
extension Plan2DView {
    /// 사람·발화지점과 콘센트. 크기를 도면 길이로 정해 확대하면 함께 커진다
    private var stamps: some View {
        ZStack(alignment: .topLeading) {
            ForEach(planData.markers) { marker in
                stampIcon(marker.kind == .person ? EditTool.person.iconName : EditTool.ignitionPoint.iconName, size: Self.iconSize(of: marker))
                    // 테두리도 스탬프와 함께 돈다. 손잡이도 테두리 모서리를 따라 돈다
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
    private func stampIcon(_ systemName: String, size meters: Double = Self.stampSize) -> some View {
        let size = screen.length(meters)
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
                .padding(-Self.selectionPadding)
        }
    }

    /// 공간 이름 캡슐. 글자는 확대해도 같은 크기다
    private var roomLabels: some View {
        ZStack(alignment: .topLeading) {
            ForEach(planData.rooms) { room in
                if room.id != editingRoomId && !hiddenLabelRoomIds.contains(room.id) {
                    roomLabel(room)
                        .overlay { selectionBorder(isSelected: room.id == selectedRoomId) }
                        .position(screen.point(SIMD2(room.labelX, room.labelY)))
                }
            }
        }
    }

    /// 공간 이름 캡슐. 받을 곳이 있으면 누르면 이름 고치기, 끌면 자리 옮기기를 알린다
    @ViewBuilder
    private func roomLabel(_ room: Room) -> some View {
        if let actions = roomLabelActions {
            RoomLabelView(name: room.name)
                .onTapGesture { actions.onTap(room.id) }
                .gesture(
                    // 캡슐이 손가락을 따라 움직이므로, 움직인 거리는 캡슐이 아니라 화면 기준으로 잰다
                    DragGesture(minimumDistance: Layout.labelDragDistance, coordinateSpace: .global)
                        .onChanged { actions.onDrag(room.id, $0.translation) }
                        .onEnded { _ in actions.onDragEnded() }
                )
        } else {
            RoomLabelView(name: room.name)
                .allowsHitTesting(false)
        }
    }
}

// 레이아웃 값
extension Plan2DView {
    private enum Layout {
        /// 벽이 아주 얇아도 이만큼(pt)은 보이게
        static let minimumWallWidth = 1.0
        static let openingLineWidth: CGFloat = 1
        /// 고른 창문·문의 기호 두께와 바탕 띠 진하기
        static let selectedOpeningLineWidth: CGFloat = 2
        static let selectedOpeningOpacity = 0.3
        /// 고른 테두리 두께 (pt)
        static let selectionLineWidth: CGFloat = 1.5
        /// 공간 이름 캡슐을 이만큼(pt) 움직여야 끌기로 본다. 그보다 짧으면 누르기
        static let labelDragDistance: CGFloat = 4
        /// 가구 테두리 두께 (pt)
        static let furnitureLineWidth: CGFloat = 1
        /// 바닥에서 이보다(m) 높이 띄운 가구는 테두리를 점선으로
        static let floatingElevation = 0.01
        /// 띄운 가구 테두리 점선 (pt): 선 5, 빈칸 3
        static let floatingDash: [CGFloat] = [5, 3]
    }
}

#Preview {
    GeometryReader { proxy in
        Plan2DView(planData: DummyFloorPlan.planData, screen: PlanScreen(plan: DummyFloorPlan.planData, in: proxy.size, fill: 0.8))
    }
}

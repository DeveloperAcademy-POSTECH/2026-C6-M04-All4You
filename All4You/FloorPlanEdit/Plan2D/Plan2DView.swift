// 도면을 위에서 본 2D 그림. 벽·문·창문은 선으로, 가구는 윗면 모양으로, 스탬프는 아이콘으로, 공간·가구 이름은 캡슐로 그린다
// 그리기만 한다. 누르기·끌기는 이 그림을 쓰는 화면이 붙인다 (공간 이름 캡슐은 roomLabelActions로 누르기·끌기를 알린다. 가구 이름 캡슐은 화면이 누른 자리로 판정한다)

import SwiftUI

/// planData를 screen의 배율과 자리에 맞춰 그린다
struct Plan2DView: View {
    let planData: PlanData
    let screen: PlanScreen
    /// 고른 표시를 그릴 요소. 스탬프는 주황 사각 테두리, 벽·창문·가구는 주황 선
    var selection: PlanSelection? = nil
    /// 이름을 고치는 중이라 캡슐 대신 입력칸을 띄울 방 (Room.id). 이 방의 캡슐은 그리지 않는다
    var editingRoomId: String? = nil
    /// 고른 표시(주황 사각 테두리)를 그릴 공간 이름 캡슐 (Room.id)
    var selectedRoomId: String? = nil
    /// 함께 고른 벽들 (Wall.id). 일직선 줄 전체를 고르면 여러 개다
    var selectedWallIds: Set<String> = []
    /// 공간 이름 캡슐을 누르거나 끌 때 알릴 곳. nil이면 캡슐은 보기만 한다
    var roomLabelActions: RoomLabelActions? = nil
    /// 이름을 고치는 중이라 캡슐 대신 입력칸을 띄울 가구 (Furniture.id). 이 가구의 이름 캡슐은 그리지 않는다
    var editingFurnitureId: String? = nil
    /// 이름 캡슐을 그리지 않을 방들 (Room.id). 사건 메인에서 사진 핀 캡슐이 이름을 대신하는 방에 쓴다
    var hiddenLabelRoomIds: Set<String> = []
    /// 치수·면적 글자 설정. 켜져 있으면 고른 종류의 글자를 도면 위에 띄운다
    var dimensions = DimensionDisplay()
    /// 도면을 확대·축소하면 이름 캡슐도 함께 키우고 줄일지 (한계는 LabelScale). false면 늘 같은 크기다
    var scalesLabels = false
    /// 발화지점·전기 스탬프 아래에 종류 글자를 보일지. 내보내기 도면은 바닥 스탬프를 비우고 그려서 벽 전기 글자만 남지 않게 끈다
    var showsStampKinds = true
    /// 라벨 글자를 고치는 중이라 라벨 대신 입력칸을 띄울 스탬프 (PlanMarker.id·WallFixture.id). 이 스탬프의 종류 라벨은 그리지 않는다
    var editingKindNoteId: String? = nil

    /// 지금 이름 캡슐 배율
    private var labelScale: CGFloat {
        scalesLabels ? screen.labelScale : 1
    }

    /// 사람·발화지점 아이콘 크기 (m). 3D 모델이 바닥에서 차지하는 자리의 긴 쪽 길이라 2D와 3D 크기가 비슷하다.
    /// 사람은 몸 길이(누운 몸), 발화지점은 지름이다. 서 있는 사람 아이콘은 이 길이만큼 키로 그린다
    static func iconSize(of marker: PlanMarker) -> Double {
        let footprint = marker.footprint
        let delta = footprint.end - footprint.start
        return max((delta * delta).sum().squareRoot(), footprint.radius * 2)
    }
    /// 표시 종류별 아이콘. 도구 막대의 같은 이름 도구와 같은 모양이다
    static func iconName(of kind: MarkerKind) -> String {
        switch kind {
        case .person: EditTool.person.iconName
        case .ignitionPoint: EditTool.ignitionPoint.iconName
        case .outlet: EditTool.outlet.iconName
        }
    }
    /// 아이콘에서 고른 테두리까지 (pt). 손잡이도 이 테두리 모서리에 붙는다
    static let selectionPadding: CGFloat = 6
    /// 고른 테두리와 종류 라벨 사이 (pt)
    static let kindLabelGap: CGFloat = 2
    /// 종류 라벨과 그 사각 테두리 사이 (pt)
    static let kindLabelBoxPadding: CGFloat = 4

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
        // 치수 글자는 누르지 않고 보기만 한다
        .overlay {
            dimensionLayer
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
    /// 고른 캡슐의 ✕를 눌렀다 (Room.id)
    let onDelete: (String) -> Void
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
        if isSelected && opening.kind == .door {
            // 문은 문짝이 열리는 자리까지 주황 사각형으로 감싼다 (창문은 아래 띠)
            var box = Path()
            let across = line.leftNormal * opening.width
            let along = line.direction * opening.width
            let back = line.leftNormal * (-wall.thickness / 2)
            let corners = [start + back, start + back + along, start + across + along, start + across]
            box.addLines(corners.map(screen.point))
            box.closeSubpath()
            context.stroke(box, with: .color(.brand500), style: StrokeStyle(lineWidth: Layout.selectionLineWidth))
        } else if isSelected {
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
    /// 가구 윗면을 옅은 회색으로 채우고 테두리를 긋는다. 바닥에서 띄운 가구(벽 수납장 등)는 테두리를 점선으로, 고른 가구는 주황 굵은 테두리로
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
        let isSelected = selection == .furniture(furniture.id)
        context.fill(path, with: .color(.gray100))
        context.stroke(
            path,
            with: .color(isSelected ? .brand500 : .gray500),
            style: StrokeStyle(lineWidth: isSelected ? Layout.selectionLineWidth : Layout.furnitureLineWidth, dash: isFloating ? Layout.floatingDash : [])
        )
    }

    /// 가구 가운데의 이름 캡슐. 가구를 돌려도 글자는 바로 선다. 고른 가구의 캡슐은 공간 이름처럼 주황 테두리.
    /// 테두리까지 함께 키우고 줄인다
    private var furnitureLabels: some View {
        ZStack(alignment: .topLeading) {
            ForEach(planData.furniture ?? []) { furniture in
                if furniture.id != editingFurnitureId {
                    FurnitureLabelView(label: furniture.label)
                        .overlay { selectionBorder(isSelected: selection == .furniture(furniture.id)) }
                        .scaleEffect(labelScale)
                        // 누르기는 화면이 판정한다 (Plan2DHitTest). 스탬프가 가구 이름 위에 겹치면 스탬프가 먼저 눌리게 하려고 캡슐 자체는 누르지 않는다
                        .allowsHitTesting(false)
                        .position(screen.point(furniture.center))
                }
            }
        }
    }
}

// 치수선·면적
extension Plan2DView {
    /// 켜 둔 종류의 치수선과 면적 글자. 눌리지 않고 보기만 한다. 글자가 선에 안 들어가거나 먼저 그린 글자와 겹치는 것은 그리지 않는다
    private var dimensionLayer: some View {
        Canvas { context, _ in
            guard dimensions.isShown else { return }
            let marks = planData.dimensionMarks(kinds: dimensions.kinds)
            for area in marks.areas where area.polygon.count >= 3 {
                var path = Path()
                path.addLines(area.polygon.map { screen.point($0) })
                path.closeSubpath()
                context.fill(path, with: .color(.brand500.opacity(Layout.roomTintOpacity)))
            }
            var slots: [DimensionSlot] = []
            for line in marks.lines {
                let start = screen.point(line.start)
                let end = screen.point(line.end)
                let size = DimensionDeclutter.estimatedSize(of: line.text, scale: labelScale)
                // 글자가 선 안에 들어가지 않을 만큼 짧아진 선은 후보에서 뺀다
                guard hypot(end.x - start.x, end.y - start.y) >= size.width + Layout.lineTextMargin else { continue }
                slots.append(DimensionSlot(id: line.id, kind: line.kind, center: CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2), size: size))
            }
            for area in marks.areas {
                let point = screen.point(area.point)
                slots.append(DimensionSlot(
                    id: area.id, kind: area.kind, center: CGPoint(x: point.x, y: point.y + belowOffset(of: area)),
                    size: DimensionDeclutter.estimatedSize(of: area.text, scale: labelScale)
                ))
            }
            let visible = DimensionDeclutter.visibleIds(slots)
            for line in marks.lines where visible.contains(line.id) {
                drawDimensionLine(line, in: &context)
            }
            for area in marks.areas where visible.contains(area.id) {
                let point = screen.point(area.point)
                drawDimensionText(area.text, at: CGPoint(x: point.x, y: point.y + belowOffset(of: area)), color: area.kind.color, in: &context)
            }
        }
        .allowsHitTesting(false)
    }

    /// 보조선 둘, 치수선, 양 끝 눈금, 가운데 글자
    private func drawDimensionLine(_ line: DimensionLine, in context: inout GraphicsContext) {
        let start = screen.point(line.start)
        let end = screen.point(line.end)
        let anchorStart = screen.point(line.anchorStart)
        let anchorEnd = screen.point(line.anchorEnd)
        let length = hypot(end.x - start.x, end.y - start.y)
        guard length > 0 else { return }
        let direction = CGPoint(x: (end.x - start.x) / length, y: (end.y - start.y) / length)
        let normal = CGPoint(x: -direction.y, y: direction.x)
        let tick = Layout.tickLength * labelScale
        let color = line.kind.color
        var path = Path()
        // 보조선은 대상 쪽 끝에서 시작해 치수선을 조금 넘어선다
        for (anchor, point) in [(anchorStart, start), (anchorEnd, end)] {
            let away = hypot(point.x - anchor.x, point.y - anchor.y)
            guard away > 0 else { continue }
            let past = Layout.extensionOvershoot / away
            path.move(to: anchor)
            path.addLine(to: CGPoint(x: point.x + (point.x - anchor.x) * past, y: point.y + (point.y - anchor.y) * past))
        }
        context.stroke(path, with: .color(color.opacity(Layout.extensionOpacity)), lineWidth: Layout.extensionLineWidth)
        var main = Path()
        main.move(to: start)
        main.addLine(to: end)
        // 눈금은 치수선에 45° 기울인 짧은 선 (건축 도면의 치수선 끝 모양)
        for point in [start, end] {
            let slash = CGPoint(x: (direction.x + normal.x) * tick / 2, y: (direction.y + normal.y) * tick / 2)
            main.move(to: CGPoint(x: point.x - slash.x, y: point.y - slash.y))
            main.addLine(to: CGPoint(x: point.x + slash.x, y: point.y + slash.y))
        }
        context.stroke(main, with: .color(color), lineWidth: Layout.dimensionLineWidth)
        drawDimensionText(line.text, at: CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2), color: color, in: &context)
    }

    /// at을 가운데로 흰 윤곽이 있는 주황 글자를 그린다. 글자는 도면 배율에 맞춰 키우고 줄인다
    private func drawDimensionText(_ text: String, at point: CGPoint, color: Color, in context: inout GraphicsContext) {
        let font = AppTypography.label.weight(.semibold)
        let halo = context.resolve(Text(text).font(font).foregroundStyle(Color.white))
        let main = context.resolve(Text(text).font(font).foregroundStyle(color))
        var scaled = context
        scaled.translateBy(x: point.x, y: point.y)
        scaled.scaleBy(x: labelScale, y: labelScale)
        for offset in DimensionTextView.haloOffsets {
            scaled.draw(halo, at: CGPoint(x: offset.width, y: offset.height))
        }
        scaled.draw(main, at: .zero)
    }

    /// 이름 캡슐 아래로 내릴 거리 (pt). 캡슐도 함께 커지고 줄어 같은 배율을 곱한다
    private func belowOffset(of area: DimensionArea) -> CGFloat {
        switch area.below {
        case .room?: Layout.roomCapsuleBelow * labelScale
        case .furniture?: Layout.furnitureCapsuleBelow * labelScale
        case nil: 0
        }
    }
}

// 스탬프와 공간 이름
extension Plan2DView {
    /// 사람·발화지점과 콘센트. 크기를 도면 길이로 정해 확대하면 함께 커진다
    private var stamps: some View {
        ZStack(alignment: .topLeading) {
            ForEach(planData.markers) { marker in
                stampIcon(Self.iconName(of: marker.kind), size: Self.iconSize(of: marker))
                    // 테두리도 스탬프와 함께 돈다. 손잡이도 테두리 모서리를 따라 돈다
                    .overlay { selectionBorder(isSelected: selection == .marker(marker.id)) }
                    .rotationEffect(.degrees(marker.yaw))
                    .position(screen.point(marker.position))
                // 종류 글자는 스탬프를 돌려도 바로 서고, 스탬프 아래에 놓인다
                kindLabel(marker.kindLabel, id: marker.id, isBoxed: marker.isKindOther && selection == .marker(marker.id), at: marker.position, iconSize: Self.iconSize(of: marker))
            }
            ForEach(planData.wallFixtures) { fixture in
                if let point = planData.point(of: fixture) {
                    stampIcon(EditTool.outlet.iconName)
                        .overlay { selectionBorder(isSelected: selection == .wallFixture(fixture.id)) }
                        .position(screen.point(point))
                    kindLabel(fixture.kindLabel, id: fixture.id, isBoxed: fixture.isKindOther && selection == .wallFixture(fixture.id), at: point, iconSize: screen.outletSize)
                }
            }
        }
    }

    /// 스탬프 아래의 종류 글자 캡슐. 종류가 없으면 그리지 않는다. 고른 테두리 바로 아래에 두고, 눌리지 않는다.
    /// 고른 기타 스탬프(isBoxed)는 라벨에만 따로 주황 사각 테두리를 쳐서, 이 테두리를 누르면 글자를 고칠 수 있음을 보인다.
    /// 캡슐은 가운데 기준으로 키우고 줄므로, 키운 높이의 절반만큼 더 내려서 스탬프와 겹치지 않게 한다
    @ViewBuilder
    private func kindLabel(_ text: String?, id: String, isBoxed: Bool, at point: SIMD2<Double>, iconSize: Double) -> some View {
        if showsStampKinds, id != editingKindNoteId, let text {
            StampKindLabelView(text: text)
                .overlay {
                    if isBoxed {
                        Rectangle()
                            .stroke(.brand500, lineWidth: Layout.selectionLineWidth)
                            .padding(-Self.kindLabelBoxPadding)
                    }
                }
                .scaleEffect(labelScale)
                .allowsHitTesting(false)
                .position(screen.kindLabelCenter(at: point, iconSize: iconSize, labelScale: labelScale))
        }
    }

    /// 아이콘을 스탬프 크기의 정사각형 안 가운데에 둔다. 테두리가 아이콘 모양과 상관없이 같은 크기가 되게
    private func stampIcon(_ systemName: String, size meters: Double? = nil) -> some View {
        let size = screen.length(meters ?? screen.outletSize)
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
                        .overlay(alignment: .topLeading) { roomDeleteHandle(room) }
                        // 테두리·✕ 자리까지 한 덩어리로 키우고 줄인다
                        .scaleEffect(labelScale)
                        .position(screen.point(SIMD2(room.labelX, room.labelY)))
                }
            }
        }
    }

    /// 고른 공간 이름 캡슐 왼쪽 위 모서리의 ✕. 스탬프의 ✕ 손잡이와 같은 모양
    @ViewBuilder
    private func roomDeleteHandle(_ room: Room) -> some View {
        if room.id == selectedRoomId, let actions = roomLabelActions {
            Button { actions.onDelete(room.id) } label: {
                Image(systemName: "xmark")
                    .font(AppTypography.title3)
                    .foregroundStyle(.brand500)
                    .frame(width: Layout.deleteHandleSize, height: Layout.deleteHandleSize)
                    .glassEffect(.regular, in: .circle)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("삭제")
            // 캡슐과 함께 커지지 않고 늘 같은 크기로 모서리에 붙는다
            .scaleEffect(1 / labelScale)
            .offset(x: -Layout.deleteHandleSize / 2, y: -Layout.deleteHandleSize / 2)
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
        /// 방 바닥을 칠하는 옅은 주황의 진하기
        static let roomTintOpacity = 0.08
        /// 치수선 굵기와 끝 눈금 길이 (pt)
        static let dimensionLineWidth: CGFloat = 1
        static let tickLength: CGFloat = 8
        /// 보조선 굵기·진하기와, 치수선을 넘어서 더 나가는 길이 (pt)
        static let extensionLineWidth: CGFloat = 0.5
        static let extensionOpacity = 0.6
        static let extensionOvershoot: CGFloat = 4
        /// 치수선이 글자 너비보다 이만큼(pt) 더 길어야 그린다
        static let lineTextMargin: CGFloat = 16
        /// 면적 글자를 이름 캡슐 가운데에서 아래로 내리는 거리 (pt). 캡슐 반 높이에 글자 반 높이와 여유를 더한 값
        static let roomCapsuleBelow: CGFloat = 32
        static let furnitureCapsuleBelow: CGFloat = 26
        /// 공간 이름 캡슐을 이만큼(pt) 움직여야 끌기로 본다. 그보다 짧으면 누르기
        static let labelDragDistance: CGFloat = 4
        /// 고른 공간 이름 캡슐의 ✕ 손잡이 크기 (pt). 스탬프 손잡이와 같다
        static let deleteHandleSize: CGFloat = 44
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

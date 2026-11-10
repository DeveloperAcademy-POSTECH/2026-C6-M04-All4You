// 도면을 3D로 보여 주는 뷰. 한 손가락으로 돌리고, 두 손가락으로 확대·축소하고 끌어 옮긴다
//
// 카메라는 직접 돌린다. 애플 기본 조작(.realityViewCameraControls(.orbit))은 스탬프·창문을 끄는 동안 껐다 켜면
// 도면을 옮긴 뒤 카메라가 갑자기 다른 자리로 튀어서 쓰지 않는다. 확대는 도면 자체를 원점 기준으로 키우고 줄인다

import RealityKit
import SwiftUI

struct FloorPlan3DView: View {
    let planData: PlanData
    /// 고른 표시로 그릴 도면 요소
    let selection: PlanSelection?
    /// 누른 자리를 도면 기준 값으로 바꿔 알린다. 아무것도 안 맞으면 nil
    let onTap: (PlanTap?) -> Void
    /// 고른 스탬프를 옮기거나 돌리거나 복제·삭제하면 알린다
    let onEdit: (PlanEdit) -> Void
    /// 도면 위에 띄울 핀 (사진·메모 등). 공간 이름 라벨처럼 3D 자리를 화면 점으로 바꿔 겹치고, 벽에 가려지면 숨긴다
    var pins: [Plan3DPin] = []
    /// 핀 하나를 그리는 뷰 (Plan3DPin.id를 받음). nil이면 핀을 그리지 않는다
    var pinView: ((String) -> AnyView)? = nil
    /// 위 스탬프 도구가 켜져 있는지. 켜져 있으면 가구 위를 눌러도 가구를 고르지 않고 그 아래 바닥에 스탬프를 놓는다
    var isStampToolActive = false

    /// 도면 엔티티를 담는 자리. 도면이 바뀌면 이 안만 다시 만든다
    @State private var sceneRoot = Entity()
    /// 원점을 바라보며 둘레를 도는 카메라
    @State private var camera = PerspectiveCamera()
    /// 카메라가 있는 방향. 한 손가락으로 끌면 바뀐다
    @State private var orbit = CameraOrbit.initial
    /// 카메라를 돌리기 시작할 때의 방향
    @State private var orbitAtDragStart: CameraOrbit?
    /// 두 손가락으로 확대하거나 옮기는 중인지. 손을 뗄 때까지 카메라를 돌리지 않는다
    @State private var isUsingTwoFingers = false
    /// 누른 화면 점에서 3D 안쪽으로 가상의 직선을 그을 때 쓰는 카메라 정보. 장면을 처음 만들 때 받아 둔다
    @State private var cameraContent: RealityViewCameraContent?
    /// 핀치를 끝냈을 때의 도면 배율. 다음 핀치는 여기서 이어 간다
    @State private var committedZoom: Float = 1
    /// 공간 이름 라벨의 화면 위치 (키 = Room.id). 카메라가 움직일 때마다 다시 계산한다
    @State private var labelPoints: [String: CGPoint] = [:]
    /// 가구 이름 라벨의 화면 위치 (키 = Furniture.id). 공간 이름 라벨과 함께 다시 계산한다
    @State private var furnitureLabelPoints: [String: CGPoint] = [:]
    /// 핀의 화면 위치 (키 = Plan3DPin.id). 라벨과 함께 다시 계산한다
    @State private var pinPoints: [String: CGPoint] = [:]
    /// 매 프레임 신호를 받는 구독. 화면이 사라지면 함께 없어진다
    @State private var frameUpdates: EventSubscription?
    /// 마지막으로 라벨 위치를 계산한 뒤 지난 시간 (초)
    @State private var timeSinceLabelUpdate: TimeInterval = 0
    /// 지금 하고 있는 한 손가락 끌기. 고른 스탬프 위에서 시작했으면 스탬프 이동, 고른 창문 테두리 손잡이면 크기 조절, 아니면 카메라 회전
    @State private var drag: DragKind?
    /// 고른 스탬프의 손잡이·메뉴 화면 위치. 스탬프(사람·발화지점·콘센트)를 골랐을 때만 있다
    @State private var stampScreenPoints: StampScreenPoints?
    /// 고른 스탬프의 엔티티. 장면을 다시 만들 때 찾아 둔다 (매 프레임 신호에서는 selection이 처음 값으로 남아 있어서)
    @State private var selectedStampEntity: Entity?
    /// 꾹 눌러 편집 메뉴를 띄운 스탬프. 고른 것이 바뀌거나 스탬프를 옮기기 시작하면 메뉴가 사라진다
    @State private var menuTarget: PlanSelection?
    /// 지금 손가락이 닿아 있는 첫 화면 점. 꾹 누르기가 어느 스탬프 위였는지 알 때 쓴다
    @State private var pressLocation: CGPoint?
    /// 고른 창문의 위 테두리 가운데 점 (sceneRoot 기준). 장면을 다시 만들 때 계산해 둔다
    @State private var selectedWindowTop: SIMD3<Float>?
    /// 창문 삭제 메뉴를 띄울 화면 위치 (위 테두리 가운데)
    @State private var windowMenuPoint: CGPoint?
    /// 창문 테두리를 끄는 동안 미리 보여 주는 도면. 손을 떼면 지우고 도면은 한 번만 바꾼다
    @State private var windowPreview: PlanData?

    var body: some View {
        RealityView { content in
            content.add(sceneRoot)
            content.add(makeLight())
            placeCamera()
            content.add(camera)
            cameraContent = content
            frameUpdates = content.subscribe(to: SceneEvents.Update.self) { [content] event in
                // 라벨마다 벽에 가려졌는지 직선을 그어 확인하므로 매 프레임이 아니라 labelUpdateInterval마다 한 번만 계산한다
                timeSinceLabelUpdate += event.deltaTime
                guard timeSinceLabelUpdate >= Layout.labelUpdateInterval else { return }
                timeSinceLabelUpdate = 0
                updateLabelPoints(using: content)
                updateStampScreenPoints(using: content)
                updateWindowMenuPoint(using: content)
            }
        }
        // TODO: 팀원이 만든 도면 미리보기에도 같은 회전·확대 조작이 있음. 나중에 하나로 통일할지 확인
        .simultaneousGesture(zoomGesture)
        .simultaneousGesture(tapGesture)
        .simultaneousGesture(longPressGesture)
        .simultaneousGesture(pressLocationGesture)
        .simultaneousGesture(stampDragGesture)
        .gesture(TwoFingerPanGesture(onChanged: panPlan, onEnded: endTwoFingers))
        // 가구 이름을 먼저 깔아, 겹치면 공간 이름이 위에 보이게 한다 (2D와 같은 순서)
        .overlay(alignment: .topLeading) {
            furnitureLabels
        }
        .overlay(alignment: .topLeading) {
            roomLabels
        }
        // 핀은 이름 라벨 위에 보이고 누를 수 있다
        .overlay(alignment: .topLeading) {
            pinLayer
        }
        .overlay(alignment: .topLeading) {
            stampControls
        }
        .overlay(alignment: .topLeading) {
            windowControls
        }
        .coordinateSpace(.named(Layout.sceneSpace))
        .onChange(of: planData, initial: true) {
            rebuildScene()
        }
        .onChange(of: windowPreview) {
            rebuildScene()
        }
        .onChange(of: pins) {
            rebuildScene()
        }
        .onChange(of: selection) {
            // 다른 것을 고르면 메뉴를 닫는다. 나중에 같은 스탬프를 다시 눌러도 꾹 누르기 전에는 메뉴가 뜨지 않게
            if menuTarget != selection { menuTarget = nil }
            rebuildScene()
        }
    }
}

// 공간·가구 이름 라벨
// iOS의 RealityView는 SwiftUI 뷰를 3D에 직접 붙일 수 없어서(visionOS 전용), 3D 점을 화면 점으로 바꿔 위에 겹치는 방법 사용
extension FloorPlan3DView {
    private var roomLabels: some View {
        ForEach(planData.rooms) { room in
            if let point = labelPoints[room.id] {
                RoomLabelView(name: room.name)
                    .position(point)
            }
        }
        .allowsHitTesting(false)
    }

    /// 2D와 같은 가구 이름 캡슐. 3D에서는 보기만 한다
    private var furnitureLabels: some View {
        ForEach(planData.furniture ?? []) { furniture in
            if let point = furnitureLabelPoints[furniture.id] {
                FurnitureLabelView(label: furniture.label)
                    .position(point)
            }
        }
        .allowsHitTesting(false)
    }

    /// 도면 위 핀. 화면 밖·벽 뒤에 있으면 그리지 않는다
    @ViewBuilder
    private var pinLayer: some View {
        if let pinView {
            ForEach(pins) { pin in
                if let point = pinPoints[pin.id] {
                    pinView(pin.id)
                        .position(point)
                }
            }
        }
    }

    /// 핀 자리 엔티티들을 모아 두는 엔티티 이름
    private static let pinAnchorsName = "pinAnchors"

    /// 핀마다 3D 자리 엔티티를 만든다. 보이는 모양은 없고 위치만 있다. 엔티티 이름 = Plan3DPin.id
    private func makePinAnchors(for plan: PlanData) -> Entity {
        let space = PlanSpace(plan: plan)
        let group = Entity()
        group.name = Self.pinAnchorsName
        for pin in pins {
            let anchor = Entity()
            anchor.name = pin.id
            anchor.position = space.world(pin.point, height: pin.height)
            group.addChild(anchor)
        }
        return group
    }

    /// 공간·가구 라벨 자리를 화면 점으로 다시 계산한다. 바뀐 것만 넣어 화면을 쓸데없이 다시 그리지 않는다
    private func updateLabelPoints(using content: RealityViewCameraContent) {
        let rooms = screenPoints(ofAnchorsIn: FloorPlan3DBuilder.roomLabelAnchorsName, content: content)
        if rooms != labelPoints {
            labelPoints = rooms
        }
        let furniture = screenPoints(ofAnchorsIn: FloorPlan3DBuilder.furnitureLabelAnchorsName, content: content)
        if furniture != furnitureLabelPoints {
            furnitureLabelPoints = furniture
        }
        let pinScreenPoints = screenPoints(ofAnchorsIn: Self.pinAnchorsName, content: content)
        if pinScreenPoints != pinPoints {
            pinPoints = pinScreenPoints
        }
    }

    /// 장면 안 라벨 자리 묶음(FloorPlan3DBuilder)을 화면 점으로 바꾼다 (키 = 자리 엔티티 이름). 카메라 뒤에 있거나 벽에 가려지면 뺀다
    private func screenPoints(ofAnchorsIn groupName: String, content: RealityViewCameraContent) -> [String: CGPoint] {
        guard let anchors = sceneRoot.findEntity(named: groupName) else { return [:] }
        var points: [String: CGPoint] = [:]
        for anchor in anchors.children {
            let position = anchor.position(relativeTo: nil)
            guard let point = content.project(point: position, to: .local),
                  !isHiddenByWall(position, at: point, content: content) else { continue }
            points[anchor.name] = point
        }
        return points
    }
    
    /// 카메라 위치와 방향을 잡아 가상의 직선을 긋는 계산식을 돌린 후, 직선이 벽과 충돌하는 결과가 나오면 라벨이 벽에 가려진 것으로 판단
    private func isHiddenByWall(_ position: SIMD3<Float>, at point: CGPoint, content: RealityViewCameraContent) -> Bool {
        guard let scene = sceneRoot.scene,
              let ray = content.ray(through: point, in: .local, to: .scene) else { return false }
        let distanceToLabel = simd_distance(ray.origin, position)
        let hits = scene.raycast(
            origin: ray.origin,
            direction: ray.direction,
            length: distanceToLabel - Layout.labelHitMargin,
            query: .nearest,
            mask: FloorPlan3DBuilder.wallCollisionGroup,
            relativeTo: nil
        )
        return !hits.isEmpty
    }
}

// 누른 자리 판정
extension FloorPlan3DView {
    private var tapGesture: some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                onTap(tapResult(at: value.location, excludingFurniture: isStampToolActive))
            }
    }

    /// 누른 화면 점에서 3D 안쪽으로 가상의 직선을 그어, 가장 먼저 부딪힌 것을 도면 기준 값으로 바꾼다
    private func tapResult(at point: CGPoint, excludingFurniture: Bool = false) -> PlanTap? {
        guard let hit = firstHit(at: point, excludingFurniture: excludingFurniture) else { return nil }
        if let element = FloorPlan3DBuilder.selection(of: hit.entity) {
            return .element(element)
        }
        // 맞은 점은 월드 좌표라 핀치 배율(sceneRoot.scale)이 들어 있다. sceneRoot 기준으로 바꿔 배율을 뺀다
        let local = sceneRoot.convert(position: hit.position, from: nil)
        let planPoint = PlanSpace(plan: planData).plan(local)
        if let wallId = FloorPlan3DBuilder.wallId(of: hit.entity) {
            return .wall(id: wallId, point: planPoint, height: Double(local.y))
        }
        return .floor(planPoint)
    }

    /// 화면 점에서 3D 안쪽으로 그은 직선이 가장 먼저 부딪힌 것
    /// excludingFurniture가 참이면 가구는 직선이 지나가게 한다
    private func firstHit(at point: CGPoint, excludingFurniture: Bool = false) -> CollisionCastHit? {
        guard let cameraContent,
              let scene = sceneRoot.scene,
              let ray = cameraContent.ray(through: point, in: .local, to: .scene) else { return nil }
        let mask = excludingFurniture ? CollisionGroup.all.subtracting(FloorPlan3DBuilder.furnitureCollisionGroup) : CollisionGroup.all
        return scene.raycast(origin: ray.origin, direction: ray.direction, query: .nearest, mask: mask, relativeTo: nil).first
    }
}

// 스탬프 끌어 옮기기
// 끄는 동안은 엔티티만 움직이고 도면은 손을 뗄 때 한 번 바꾼다 (끄는 내내 장면을 다시 만들지 않게)
extension FloorPlan3DView {
    private enum DragKind {
        case stamp(StampDrag)
        /// 고른 창문의 테두리 손잡이를 끎
        case windowEdge(windowId: String, edge: WindowEdge)
        case camera
    }

    /// 끌고 있는 스탬프와 끌기 시작할 때의 위치
    private struct StampDrag {
        let selection: PlanSelection
        let entity: Entity
        /// 콘센트가 붙은 벽 (Wall.id). 사람·발화지점은 nil이라 바닥 위에서 움직인다
        let wallId: String?
        let startPosition: SIMD3<Float>
        /// 끌기 시작한 화면 점 아래의 바닥·벽 점 (sceneRoot 기준)
        let startSurfacePoint: SIMD3<Float>
    }

    /// 스탬프나 창문 테두리를 끄는 중인지. 그동안은 카메라를 멈춘다
    private var isDraggingElement: Bool {
        switch drag {
        case .stamp?, .windowEdge?: true
        case .camera?, nil: false
        }
    }

    /// 손가락이 바닥(벽) 위에서 움직인 만큼 스탬프를 옮긴다. 콘센트는 붙은 벽 면 위에서만 움직인다.
    /// 창문 테두리 손잡이에서 시작하면 그 테두리를 옮긴다
    private var stampDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if drag == nil {
                    drag = beginWindowEdgeDrag(at: value.startLocation)
                        ?? beginStampDrag(at: value.startLocation).map(DragKind.stamp)
                        ?? .camera
                    if isDraggingElement { menuTarget = nil }
                }
                switch drag {
                case .stamp(let stampDrag)?:
                    guard let point = surfacePoint(at: value.location, wallId: stampDrag.wallId) else { return }
                    stampDrag.entity.position = stampDrag.startPosition + (point - stampDrag.startSurfacePoint)
                case .windowEdge(let windowId, let edge)?:
                    previewWindowEdge(windowId: windowId, edge: edge, at: value.location)
                case .camera?:
                    rotateCamera(by: value.translation)
                case nil:
                    break
                }
            }
            .onEnded { value in
                defer {
                    drag = nil
                    orbitAtDragStart = nil
                    isUsingTwoFingers = false
                }
                switch drag {
                case .stamp(let stampDrag)?:
                    let position = stampDrag.entity.position
                    let point = PlanSpace(plan: planData).plan(position)
                    onEdit(.move(stampDrag.selection, point: point, height: Double(position.y)))
                case .windowEdge(let windowId, let edge)?:
                    finishWindowEdge(windowId: windowId, edge: edge, at: value.location)
                case .camera?, nil:
                    break
                }
            }
    }

    /// 끌기가 고른 스탬프 위에서 시작했으면 그 스탬프를 끌 준비를 한다. 창문은 끌지 않는다
    private func beginStampDrag(at point: CGPoint) -> StampDrag? {
        guard let selection, let hit = firstHit(at: point),
              FloorPlan3DBuilder.selection(of: hit.entity) == selection,
              let entity = FloorPlan3DBuilder.selectableEntity(of: hit.entity) else { return nil }
        let wallId: String?
        switch selection {
        case .marker, .furniture:
            wallId = nil
        case .wallFixture(let id):
            guard let fixture = planData.wallFixtures.first(where: { $0.id == id }) else { return nil }
            wallId = fixture.wallId
        case .doorWindow, .wall:
            return nil
        }
        guard let start = surfacePoint(at: point, wallId: wallId) else { return nil }
        return StampDrag(selection: selection, entity: entity, wallId: wallId, startPosition: entity.position, startSurfacePoint: start)
    }

    /// 화면 점 아래의 바닥 점, 콘센트면 붙은 벽의 면 점 (sceneRoot 기준). 직선이 끌고 있는 스탬프 자신에 부딪히지 않게 바닥(벽)만 본다
    private func surfacePoint(at point: CGPoint, wallId: String?) -> SIMD3<Float>? {
        guard let cameraContent, let scene = sceneRoot.scene,
              let ray = cameraContent.ray(through: point, in: .local, to: .scene) else { return nil }
        let group = wallId == nil ? FloorPlan3DBuilder.floorCollisionGroup : FloorPlan3DBuilder.wallCollisionGroup
        let hits = scene.raycast(origin: ray.origin, direction: ray.direction, query: .all, mask: group, relativeTo: nil)
        let hit = hits
            .sorted { $0.distance < $1.distance }
            .first { wallId == nil || FloorPlan3DBuilder.wallId(of: $0.entity) == wallId }
        return hit.map { sceneRoot.convert(position: $0.position, from: nil) }
    }
}

// 고른 스탬프 위 회전 손잡이와 편집 메뉴
// 라벨처럼 고른 스탬프의 꼭대기를 화면 점으로 바꿔 위에 겹친다. 손잡이는 스탬프 둘레로 끌면 돌고(사람·발화지점만),
// 스탬프를 꾹 누르면 손잡이 대신 메뉴가 뜬다
extension FloorPlan3DView {
    /// 스탬프·창문을 꾹 누르면 그것을 고르고 회전 손잡이(창문은 테두리 손잡이) 대신 편집 메뉴를 띄운다.
    /// 꾹 누르기는 누른 자리를 알려 주지 않아서, 손가락이 닿은 자리는 pressLocationGesture가 따로 받아 둔다
    private var longPressGesture: some Gesture {
        LongPressGesture(minimumDuration: Layout.longPressDuration)
            .onEnded { _ in
                guard let pressLocation,
                      case .element(let element)? = tapResult(at: pressLocation) else { return }
                // 가구는 복제·삭제 메뉴가 없어 고르기만 한다
                switch element {
                case .furniture: break
                default: menuTarget = element
                }
                onTap(.element(element))
            }
    }

    /// 손가락이 처음 닿은 화면 점을 받아 두고, 손을 떼면 지운다
    private var pressLocationGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if pressLocation == nil { pressLocation = value.startLocation }
            }
            .onEnded { _ in
                pressLocation = nil
            }
    }

    @ViewBuilder
    private var stampControls: some View {
        if let stampScreenPoints, let selection {
            if menuTarget == selection {
                StampEditMenuView(
                    onDuplicate: { onEdit(.duplicate(selection)) },
                    onDelete: { onEdit(.delete(selection)) }
                )
                .fixedSize()
                .position(stampScreenPoints.menu)
            } else if case .marker(let id) = selection {
                RotateHandleView()
                    .position(stampScreenPoints.handle)
                    .gesture(rotateGesture(markerId: id, center: stampScreenPoints.center))
                ResizeHandleView()
                    .position(stampScreenPoints.resizeHandle)
                    .gesture(resizeGesture(markerId: id, center: stampScreenPoints.center))
            } else if case .furniture(let id) = selection {
                RotateHandleView()
                    .position(stampScreenPoints.handle)
                    .gesture(rotateFurnitureGesture(id: id, center: stampScreenPoints.center))
                ResizeHandleView()
                    .position(stampScreenPoints.resizeHandle)
                    .gesture(resizeFurnitureGesture(id: id, center: stampScreenPoints.center))
            }
        }
    }

    /// 손잡이를 스탬프 가운데를 축으로 돌리듯 끌면, 손가락이 돈 각도만큼 스탬프도 돈다.
    /// 손잡이가 움직이며 따라오므로 끈 거리는 장면 기준 좌표로 잰다
    private func rotateGesture(markerId: String, center: CGPoint) -> some Gesture {
        DragGesture(coordinateSpace: .named(Layout.sceneSpace))
            .onChanged { value in
                selectedStampEntity?.orientation = PlanSpace.orientation(yaw: rotatedYaw(markerId: markerId, drag: value, center: center))
            }
            .onEnded { value in
                onEdit(.rotate(markerId: markerId, yaw: rotatedYaw(markerId: markerId, drag: value, center: center)))
            }
    }

    /// 화면에서 손가락이 스탬프 가운데를 시계 방향으로 돈 만큼 더한 방향 (도)
    private func rotatedYaw(markerId: String, drag: DragGesture.Value, center: CGPoint) -> Double {
        let yaw = planData.markers.first { $0.id == markerId }?.yaw ?? 0
        func angle(_ point: CGPoint) -> Double { atan2(point.y - center.y, point.x - center.x) }
        return yaw + (angle(drag.location) - angle(drag.startLocation)) * 180 / .pi
    }

    /// 크기 손잡이를 가운데에서 멀어지게 끌면 커지고, 가까워지게 끌면 작아진다. 끄는 동안은 엔티티만 키우고 손을 뗄 때 도면을 한 번 바꾼다
    private func resizeGesture(markerId: String, center: CGPoint) -> some Gesture {
        DragGesture(coordinateSpace: .named(Layout.sceneSpace))
            .onChanged { value in
                selectedStampEntity?.scale = SIMD3(repeating: Float(resizedScale(markerId: markerId, drag: value, center: center)))
            }
            .onEnded { value in
                onEdit(.resize(markerId: markerId, scale: resizedScale(markerId: markerId, drag: value, center: center)))
            }
    }

    /// 화면에서 가운데와 손가락 사이 거리가 늘어난 비율만큼 곱한 배율. 2D와 같은 범위 안으로 맞춘다
    private func resizedScale(markerId: String, drag: DragGesture.Value, center: CGPoint) -> Double {
        let scale = planData.markers.first { $0.id == markerId }?.drawScale ?? 1
        func distance(_ point: CGPoint) -> Double { hypot(point.x - center.x, point.y - center.y) }
        let resized = scale * distance(drag.location) / max(distance(drag.startLocation), 1)
        return min(max(resized, PlanData.markerScaleRange.lowerBound), PlanData.markerScaleRange.upperBound)
    }

    /// 가구 회전 손잡이. 사람·발화지점과 같이 손가락이 가구 가운데를 돈 각도만큼 돌린다. 도면의 가구 방향은 라디안, 위에서 볼 때 시계 방향이 +
    private func rotateFurnitureGesture(id: String, center: CGPoint) -> some Gesture {
        DragGesture(coordinateSpace: .named(Layout.sceneSpace))
            .onChanged { value in
                let rotation = rotatedFurniture(id: id, drag: value, center: center)
                selectedStampEntity?.orientation = simd_quatf(angle: Float(-rotation), axis: [0, 1, 0])
            }
            .onEnded { value in
                onEdit(.rotateFurniture(id: id, rotation: rotatedFurniture(id: id, drag: value, center: center)))
            }
    }

    private func rotatedFurniture(id: String, drag: DragGesture.Value, center: CGPoint) -> Double {
        let rotation = planData.furniture?.first { $0.id == id }?.rotation ?? 0
        func angle(_ point: CGPoint) -> Double { atan2(point.y - center.y, point.x - center.x) }
        return rotation + angle(drag.location) - angle(drag.startLocation)
    }

    /// 가구 크기 손잡이. 가운데에서 멀어지게 끌면 가로·세로가 같은 비율로 커지고, 가까워지게 끌면 작아진다.
    /// 끄는 동안은 미리 보기 도면으로 장면을 다시 만들고(엔티티 배율을 바꾸면 높이도 함께 변하므로), 손을 떼면 도면을 한 번 바꾼다
    private func resizeFurnitureGesture(id: String, center: CGPoint) -> some Gesture {
        DragGesture(coordinateSpace: .named(Layout.sceneSpace))
            .onChanged { value in
                guard let size = resizedFurniture(id: id, drag: value, center: center) else { return }
                var preview = planData
                preview.resizeFurniture(id: id, width: size.width, depth: size.depth)
                windowPreview = preview
            }
            .onEnded { value in
                windowPreview = nil
                guard let size = resizedFurniture(id: id, drag: value, center: center) else { return }
                onEdit(.resizeFurniture(id: id, width: size.width, depth: size.depth))
            }
    }

    private func resizedFurniture(id: String, drag: DragGesture.Value, center: CGPoint) -> (width: Double, depth: Double)? {
        guard let furniture = planData.furniture?.first(where: { $0.id == id }) else { return nil }
        func distance(_ point: CGPoint) -> Double { hypot(point.x - center.x, point.y - center.y) }
        let ratio = distance(drag.location) / max(distance(drag.startLocation), 1)
        return (max(furniture.width * ratio, Furniture.minSize), max(furniture.depth * ratio, Furniture.minSize))
    }

    /// 사람의 회전 손잡이를 둘 3D 점. 머리에서 몸 바깥쪽으로 조금 더 나간 머리 높이라, 위에서 내려다봐도 머리와 겹치지 않는다.
    /// 머리가 없는 스탬프(발화지점·콘센트)는 nil
    private func personHandleAnchor(of entity: Entity, center: SIMD3<Float>) -> SIMD3<Float>? {
        guard let head = entity.findEntity(named: FloorPlan3DBuilder.headName)?.position(relativeTo: nil) else { return nil }
        var outward = head - center
        outward.y = 0
        guard simd_length(outward) > 0.001 else { return head }
        return head + simd_normalize(outward) * Layout.handleBeyondHead * sceneRoot.scale.x
    }

    /// 고른 스탬프의 화면 위치들을 잡는다. 손잡이는 사람이면 머리 너머 머리 높이, 아니면 꼭대기 위.
    /// 매 프레임 다시 계산하므로 돌리는 동안 손잡이가 머리를 따라간다. 카메라 뒤에 있으면 숨긴다
    private func updateStampScreenPoints(using content: RealityViewCameraContent) {
        var points: StampScreenPoints?
        if let entity = selectedStampEntity {
            let center = entity.position(relativeTo: nil)
            let topY = entity.visualBounds(relativeTo: nil).max.y
            func above(_ p: SIMD3<Float>) -> CGPoint? {
                content.project(point: SIMD3(p.x, topY, p.z), to: .local).map { CGPoint(x: $0.x, y: $0.y - Layout.rotateHandleGap) }
            }
            let handle = personHandleAnchor(of: entity, center: center)
                .flatMap { content.project(point: $0, to: .local) } ?? above(center)
            if let screenCenter = content.project(point: center, to: .local),
               let menu = above(center), let handle {
                // 크기 손잡이는 가운데의 오른쪽 아래. 스탬프가 화면에서 커 보일수록 멀리 둔다
                let reach = max(screenCenter.y - menu.y - Layout.rotateHandleGap, 0) + Layout.resizeHandleGap
                let resizeHandle = CGPoint(x: screenCenter.x + reach, y: screenCenter.y + reach / 2)
                points = StampScreenPoints(center: screenCenter, menu: menu, handle: handle, resizeHandle: resizeHandle)
            }
        }
        if points != stampScreenPoints {
            stampScreenPoints = points
        }
    }
}

/// 고른 스탬프의 화면 점들 (장면 기준)
private struct StampScreenPoints: Equatable {
    /// 스탬프가 도는 중심
    let center: CGPoint
    /// 편집 메뉴 자리 (가운데 꼭대기 위)
    let menu: CGPoint
    /// 회전 손잡이 자리 (사람은 머리 너머 머리 높이)
    let handle: CGPoint
    /// 크기 손잡이 자리 (가운데의 오른쪽 아래)
    let resizeHandle: CGPoint
}

// 고른 창문의 테두리 손잡이와 편집 메뉴
// 테두리 손잡이(FloorPlan3DBuilder가 3D 막대로 만듦)를 끌면 그 테두리만 움직여 폭·높이가 바뀌고(위치 이동은 없음),
// 창문을 꾹 누르면 손잡이 대신 삭제 메뉴가 뜬다
extension FloorPlan3DView {
    /// 위 테두리 위에 띄우는 삭제 메뉴. 창문은 복제하지 않는다
    @ViewBuilder
    private var windowControls: some View {
        if case .doorWindow(let id)? = selection, menuTarget == selection, let windowMenuPoint {
            StampEditMenuView(onDuplicate: nil, onDelete: { onEdit(.delete(.doorWindow(id))) })
                .fixedSize()
                .position(x: windowMenuPoint.x, y: windowMenuPoint.y - Layout.windowMenuGap)
        }
    }

    /// 끌기가 고른 창문의 테두리 손잡이 위에서 시작했으면 그 테두리를 끌 준비를 한다
    private func beginWindowEdgeDrag(at point: CGPoint) -> DragKind? {
        guard case .doorWindow(let id)? = selection, let hit = firstHit(at: point),
              let edge = FloorPlan3DBuilder.windowEdge(of: hit.entity) else { return nil }
        return .windowEdge(windowId: id, edge: edge)
    }

    /// 끄는 동안은 미리 보기 도면만 바꾼다
    private func previewWindowEdge(windowId: String, edge: WindowEdge, at point: CGPoint) {
        guard let spot = wallSpot(at: point, windowId: windowId) else { return }
        var preview = planData
        preview.resizeWindow(id: windowId, edge: edge, along: spot.along, height: spot.height)
        windowPreview = preview
    }

    /// 손을 떼면 미리 보기를 지우고 도면을 한 번 바꾼다
    private func finishWindowEdge(windowId: String, edge: WindowEdge, at point: CGPoint) {
        windowPreview = nil
        guard let spot = wallSpot(at: point, windowId: windowId) else { return }
        onEdit(.resizeWindow(id: windowId, edge: edge, along: spot.along, height: spot.height))
    }

    /// 화면 점에서 그은 직선이 창문이 달린 벽의 가운데 면과 만나는 자리 (벽 시작점에서 거리, 바닥에서 높이, m).
    /// 벽 상자에 직선을 쏘면 창문 구멍 위에서는 맞는 것이 없어서, 벽 면과 만나는 점을 직접 계산한다
    private func wallSpot(at point: CGPoint, windowId: String) -> (along: Double, height: Double)? {
        guard let cameraContent,
              let window = planData.doorWindows.first(where: { $0.id == windowId }),
              let wall = planData.wall(id: window.wallId), let line = planData.line(of: wall),
              let ray = cameraContent.ray(through: point, in: .local, to: .scene) else { return nil }
        // 핀치 배율을 빼려고 직선을 sceneRoot 기준으로 바꾼다
        let origin = sceneRoot.convert(position: ray.origin, from: nil)
        let direction = sceneRoot.convert(direction: ray.direction, from: nil)
        let space = PlanSpace(plan: planData)
        let wallStart = space.world(line.start)
        let normal = SIMD3<Float>(Float(line.leftNormal.x), 0, Float(line.leftNormal.y))
        let facing = simd_dot(direction, normal)
        // 직선이 벽 면과 거의 나란하면 만나는 점이 너무 멀어 쓰지 않는다
        guard abs(facing) > 0.0001 else { return nil }
        let hit = origin + direction * (simd_dot(wallStart - origin, normal) / facing)
        let along = ((space.plan(hit) - line.start) * line.direction).sum()
        return (along, Double(hit.y))
    }

    /// 고른 창문의 위 테두리 가운데 점 (sceneRoot 기준). 창문이 아니면 nil
    private func windowTop(of selection: PlanSelection?, in plan: PlanData) -> SIMD3<Float>? {
        guard case .doorWindow(let id)? = selection,
              let window = plan.doorWindows.first(where: { $0.id == id }),
              let wall = plan.wall(id: window.wallId), let line = plan.line(of: wall) else { return nil }
        let point = line.point(along: window.centerAlongWall)
        return PlanSpace(plan: plan).world(point, height: window.sillHeight + window.height)
    }

    /// 위 테두리 점을 화면 점으로 바꾼다. 카메라 뒤에 있으면 nil
    private func updateWindowMenuPoint(using content: RealityViewCameraContent) {
        let point = selectedWindowTop.flatMap {
            content.project(point: sceneRoot.convert(position: $0, to: nil), to: .local)
        }
        if point != windowMenuPoint {
            windowMenuPoint = point
        }
    }
}

// 확대
extension FloorPlan3DView {
    /// 손가락 벌린 비율이 m이면 도면을 m^(zoomPower)만큼 키운다
    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                beginTwoFingers()
                sceneRoot.scale = SIMD3(repeating: zoom(for: value.magnification))
            }
            .onEnded { value in
                committedZoom = zoom(for: value.magnification)
                endTwoFingers()
            }
    }

    private func zoom(for magnification: CGFloat) -> Float {
        let factor = pow(Float(magnification), Layout.zoomPower)
        return min(max(committedZoom * factor, Layout.zoomRange.lowerBound), Layout.zoomRange.upperBound)
    }
}

// 카메라 돌리기
extension FloorPlan3DView {
    /// 원점에서 본 카메라 방향. 가로로 끌면 둘레를 돌고, 세로로 끌면 위아래로 기운다
    struct CameraOrbit {
        /// 위에서 볼 때 도는 각 (라디안)
        var yaw: Float
        /// 바닥에서 올려다본 각 (라디안)
        var pitch: Float

        /// 처음 카메라 방향 (도면 앞쪽 오른쪽 위)
        static var initial: CameraOrbit {
            let direction = normalize(Layout.cameraDirection)
            return CameraOrbit(yaw: atan2(direction.x, direction.z), pitch: asin(direction.y))
        }

        var direction: SIMD3<Float> {
            SIMD3(cos(pitch) * sin(yaw), sin(pitch), cos(pitch) * cos(yaw))
        }
    }

    /// 끌기 시작한 방향에서 손가락이 움직인 만큼 카메라를 돌린다. 두 손가락을 쓰는 중이면 돌리지 않는다
    private func rotateCamera(by translation: CGSize) {
        guard !isUsingTwoFingers else { return }
        let start = orbitAtDragStart ?? orbit
        orbitAtDragStart = start
        orbit.yaw = start.yaw - Float(translation.width) * Layout.orbitSpeed
        orbit.pitch = min(max(start.pitch + Float(translation.height) * Layout.orbitSpeed, Layout.pitchRange.lowerBound), Layout.pitchRange.upperBound)
        placeCamera()
    }

    /// 두 손가락이 닿으면 한 손가락 끌기로 이미 돌린 만큼을 되돌리고 손을 뗄 때까지 돌리지 않는다
    private func beginTwoFingers() {
        guard !isUsingTwoFingers else { return }
        isUsingTwoFingers = true
        if let start = orbitAtDragStart {
            orbit = start
            placeCamera()
        }
    }

    /// 두 손가락을 떼면 다시 돌릴 수 있다. 한 손가락 끌기가 함께 시작됐으면 그 끌기가 끝날 때 풀린다
    private func endTwoFingers() {
        if drag == nil { isUsingTwoFingers = false }
    }

    /// 도면 앞쪽 위에서 원점을 바라보게 카메라를 놓는다. 도면이 클수록 멀리 둔다
    private func placeCamera() {
        let space = PlanSpace(plan: planData)
        let distance = Float(max(space.size.x, space.size.y, Layout.minimumViewSize)) * Layout.cameraDistanceRatio
        camera.look(at: .zero, from: orbit.direction * distance, relativeTo: nil)
    }
}

// 두 손가락으로 옮기기
extension FloorPlan3DView {
    /// 손가락 아래의 바닥 점이 손가락을 따라오도록 도면 전체를 바닥과 나란히 옮긴다.
    /// 카메라가 어느 쪽을 보든 손가락 방향대로 움직인다
    private func panPlan(to location: CGPoint, from previous: CGPoint) {
        beginTwoFingers()
        guard let from = floorPoint(at: previous), let to = floorPoint(at: location) else { return }
        sceneRoot.position += SIMD3(to.x - from.x, 0, to.z - from.z)
    }

    /// 화면 점에서 3D 안쪽으로 그은 직선이 도면 바닥 높이와 만나는 점. 직선이 바닥과 거의 나란하거나 카메라 뒤면 nil
    private func floorPoint(at point: CGPoint) -> SIMD3<Float>? {
        guard let ray = cameraContent?.ray(through: point, in: .local, to: .scene),
              abs(ray.direction.y) > 0.0001 else { return nil }
        let distance = (sceneRoot.position.y - ray.origin.y) / ray.direction.y
        guard distance > 0 else { return nil }
        return ray.origin + ray.direction * distance
    }
}

// 장면 만들기
extension FloorPlan3DView {
    /// 창문 테두리를 끄는 중이면 미리 보기 도면으로 만든다
    private func rebuildScene() {
        let plan = windowPreview ?? planData
        sceneRoot.children.removeAll()
        sceneRoot.addChild(FloorPlan3DBuilder.makeScene(for: plan, selection: selection))
        sceneRoot.addChild(makePinAnchors(for: plan))
        selectedWindowTop = windowTop(of: selection, in: plan)
        switch selection {
        case .marker?, .wallFixture?, .furniture?:
            selectedStampEntity = selection.flatMap { FloorPlan3DBuilder.entity(for: $0, in: sceneRoot) }
        // 벽은 3D에서 고르지 않지만, 2D에서 고른 채로 넘어올 수 있다
        case .doorWindow?, .wall?, nil:
            selectedStampEntity = nil
        }
    }

    /// 위에서 비스듬히 비추는 빛. 벽 면마다 밝기가 달라 모양이 잘 보인다
    private func makeLight() -> DirectionalLight {
        let light = DirectionalLight()
        light.look(at: .zero, from: Layout.lightPosition, relativeTo: nil)
        return light
    }
}

// 레이아웃 값
extension FloorPlan3DView {
    private enum Layout {
        /// 카메라가 있는 쪽 (원점에서 본 방향). 오른쪽 앞 위
        static let cameraDirection = SIMD3<Float>(0.35, 0.95, 1.0)
        /// 도면 긴 변에 곱하는 카메라 거리. 세로 화면(좁은 가로 시야)에서도 도면 전체가 들어오게 함
        static let cameraDistanceRatio: Float = 1.8
        /// 도면이 아주 작아도 이만큼(m)은 보이게
        static let minimumViewSize = 3.0
        static let lightPosition = SIMD3<Float>(3, 8, 5)
        /// 확대 세기. 1이면 손가락을 벌린 만큼, 숫자를 올리면 더 민감해진다
        static let zoomPower: Float = 1.6
        /// 한 손가락으로 1pt 끌 때 카메라가 도는 각 (라디안)
        static let orbitSpeed: Float = 0.006
        /// 카메라가 기울 수 있는 범위 (라디안). 바닥 아래로 내려가거나 바로 위에서 뒤집히지 않게
        static let pitchRange: ClosedRange<Float> = 0.15...1.45
        /// 도면 배율을 이 범위 안에서만 바꾼다 (너무 작아지거나 화면을 넘지 않게)
        static let zoomRange: ClosedRange<Float> = 0.4...4
        /// 라벨 바로 앞(m)은 가림 판정에서 뺀다. 라벨 자리에 닿은 것을 벽으로 잘못 보지 않게
        static let labelHitMargin: Float = 0.05
        /// 라벨 위치·가림을 다시 계산하는 간격 (초)
        /// TEMP: 우선 여유 있게 잡은 값. 라벨을 아주 많이 띄워 보는 테스트를 하며 알맞은 값으로 조절할 예정
        static let labelUpdateInterval: TimeInterval = 1.0 / 60
        /// 스탬프 꼭대기와 회전 손잡이·편집 메뉴 가운데 사이 (pt)
        static let rotateHandleGap: CGFloat = 36
        /// 스탬프 가장자리와 크기 손잡이 사이 (pt)
        static let resizeHandleGap: CGFloat = 40
        /// 사람의 회전 손잡이를 머리에서 몸 바깥쪽으로 더 내놓는 거리 (m)
        static let handleBeyondHead: Float = 0.45
        /// 회전 손잡이를 끄는 거리를 재는 좌표 공간 이름 (3D 뷰 전체)
        static let sceneSpace = "floorPlan3D"
        /// 편집 메뉴를 띄우는 꾹 누르기 시간 (초)
        static let longPressDuration = 0.5
        /// 창문 위 테두리와 삭제 메뉴 가운데 사이 (pt)
        static let windowMenuGap: CGFloat = 40
    }
}

#Preview {
    FloorPlan3DView(planData: DummyFloorPlan.planData, selection: nil, onTap: { _ in }, onEdit: { _ in })
}

/// 3D 도면 위에 띄울 핀 하나의 자리
struct Plan3DPin: Identifiable, Equatable {
    let id: String
    /// 도면 좌표 (m)
    let point: SIMD2<Double>
    /// 바닥에서 높이 (m)
    let height: Double
}

// 도면을 3D로 보여 주는 뷰. 한 손가락으로 돌리고, 두 손가락으로 확대·축소한다
//
// 카메라 조작은 애플 기본 조작(.realityViewCameraControls(.orbit))을 쓴다.
// 기본 조작은 확대 민감도를 바꿀 수 없어서, 같은 핀치로 도면 자체를 원점 기준으로 더 키우고 줄여 확대를 세게 만든다

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

    /// 도면 엔티티를 담는 자리. 도면이 바뀌면 이 안만 다시 만든다
    @State private var sceneRoot = Entity()
    /// 누른 화면 점을 광선으로 바꿀 때 쓰는 카메라 정보. 장면을 처음 만들 때 받아 둔다
    @State private var cameraContent: RealityViewCameraContent?
    /// 핀치를 끝냈을 때의 도면 배율. 다음 핀치는 여기서 이어 간다
    @State private var committedZoom: Float = 1
    /// 공간 이름 라벨의 화면 위치 (키 = Room.id). 카메라가 움직일 때마다 다시 계산한다
    @State private var labelPoints: [String: CGPoint] = [:]
    /// 매 프레임 신호를 받는 구독. 화면이 사라지면 함께 없어진다
    @State private var frameUpdates: EventSubscription?
    /// 마지막으로 라벨 위치를 계산한 뒤 지난 시간 (초)
    @State private var timeSinceLabelUpdate: TimeInterval = 0
    /// 지금 하고 있는 한 손가락 끌기. 고른 스탬프 위에서 시작했으면 스탬프 이동, 아니면 카메라 회전
    @State private var drag: DragKind?
    /// 고른 스탬프 위 손잡이·메뉴 줄의 화면 위치. 스탬프(사람·발화지점·콘센트)를 골랐을 때만 있다
    @State private var stampControlsPoint: CGPoint?
    /// 고른 스탬프의 엔티티. 장면을 다시 만들 때 찾아 둔다 (매 프레임 신호에서는 selection이 처음 값으로 남아 있어서)
    @State private var selectedStampEntity: Entity?
    /// 회전 손잡이를 끄는 중인지. 그동안은 편집 메뉴를 숨긴다
    @GestureState private var isRotating = false

    var body: some View {
        RealityView { content in
            content.add(sceneRoot)
            content.add(makeLight())
            content.add(makeCamera())
            cameraContent = content
            frameUpdates = content.subscribe(to: SceneEvents.Update.self) { [content] event in
                // 라벨마다 광선 계산을 하므로 매 프레임이 아니라 labelUpdateInterval마다 한 번만 계산한다
                timeSinceLabelUpdate += event.deltaTime
                guard timeSinceLabelUpdate >= Layout.labelUpdateInterval else { return }
                timeSinceLabelUpdate = 0
                updateLabelPoints(using: content)
                updateStampControlsPoint(using: content)
            }
        }
        // TODO: 팀원이 만든 도면 미리보기에도 같은 회전·확대 조작이 있음. 나중에 하나로 통일할지 확인
        // 스탬프를 끄는 동안은 카메라가 같이 돌지 않게 기본 조작을 끈다
        .realityViewCameraControls(isMovingStamp ? .none : .orbit)
        .simultaneousGesture(extraZoomGesture)
        .simultaneousGesture(tapGesture)
        .simultaneousGesture(stampDragGesture)
        .overlay(alignment: .topLeading) {
            roomLabels
        }
        .overlay(alignment: .topLeading) {
            stampControls
        }
        .onChange(of: planData, initial: true) {
            rebuildScene()
        }
        .onChange(of: selection) {
            rebuildScene()
        }
    }
}

// 공간 이름 라벨
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

    /// 장면 안 라벨 자리(FloorPlan3DBuilder)를 화면 점으로 바꾸고, 카메라 뒤에 있거나 벽에 가려지면 빠지도록 한다
    private func updateLabelPoints(using content: RealityViewCameraContent) {
        guard let anchors = sceneRoot.findEntity(named: FloorPlan3DBuilder.roomLabelAnchorsName) else { return }
        var points: [String: CGPoint] = [:]
        for anchor in anchors.children {
            let position = anchor.position(relativeTo: nil)
            guard let point = content.project(point: position, to: .local),
                  !isHiddenByWall(position, at: point, content: content) else { continue }
            points[anchor.name] = point
        }
        if points != labelPoints {
            labelPoints = points
        }
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
                onTap(tapResult(at: value.location))
            }
    }

    /// 누른 화면 점에서 광선을 쏴 가장 먼저 맞은 것을 도면 기준 값으로 바꾼다
    private func tapResult(at point: CGPoint) -> PlanTap? {
        guard let hit = firstHit(at: point) else { return nil }
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

    /// 화면 점에서 쏜 광선이 가장 먼저 맞은 것
    private func firstHit(at point: CGPoint) -> CollisionCastHit? {
        guard let cameraContent,
              let scene = sceneRoot.scene,
              let ray = cameraContent.ray(through: point, in: .local, to: .scene) else { return nil }
        return scene.raycast(origin: ray.origin, direction: ray.direction, query: .nearest, relativeTo: nil).first
    }
}

/// 3D에서 누른 곳을 도면 기준 값으로 바꾼 것
enum PlanTap {
    /// 고를 수 있는 요소 (스탬프·콘센트·창문)
    case element(PlanSelection)
    /// 바닥 위 도면 점 (m)
    case floor(SIMD2<Double>)
    /// 벽 면 위 도면 점 (m)과 바닥에서 높이 (m)
    case wall(id: String, point: SIMD2<Double>, height: Double)
}

/// 3D에서 스탬프를 바꾼 것. 끌기는 손을 뗄 때 한 번 알린다
enum PlanEdit {
    /// 스탬프를 도면 점 (m)과 바닥에서 높이 (m)로 옮김. 사람·발화지점은 높이를 쓰지 않는다
    case move(PlanSelection, point: SIMD2<Double>, height: Double)
    /// 사람·발화지점(PlanMarker.id)의 방향을 yaw(도)로 바꿈
    case rotate(markerId: String, yaw: Double)
    /// 스탬프를 옆에 하나 더 만듦
    case duplicate(PlanSelection)
    /// 스탬프를 지움
    case delete(PlanSelection)
}

// 스탬프 끌어 옮기기
// 끄는 동안은 엔티티만 움직이고 도면은 손을 뗄 때 한 번 바꾼다 (끄는 내내 장면을 다시 만들지 않게)
extension FloorPlan3DView {
    private enum DragKind {
        case stamp(StampDrag)
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

    private var isMovingStamp: Bool {
        if case .stamp = drag { return true }
        return false
    }

    /// 손가락이 바닥(벽) 위에서 움직인 만큼 스탬프를 옮긴다. 콘센트는 붙은 벽 면 위에서만 움직인다
    private var stampDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if drag == nil {
                    drag = beginStampDrag(at: value.startLocation).map(DragKind.stamp) ?? .camera
                }
                guard case .stamp(let stampDrag) = drag,
                      let point = surfacePoint(at: value.location, wallId: stampDrag.wallId) else { return }
                stampDrag.entity.position = stampDrag.startPosition + (point - stampDrag.startSurfacePoint)
            }
            .onEnded { _ in
                defer { drag = nil }
                guard case .stamp(let stampDrag) = drag else { return }
                let position = stampDrag.entity.position
                let point = PlanSpace(plan: planData).plan(position)
                onEdit(.move(stampDrag.selection, point: point, height: Double(position.y)))
            }
    }

    /// 끌기가 고른 스탬프 위에서 시작했으면 그 스탬프를 끌 준비를 한다. 창문은 끌지 않는다
    private func beginStampDrag(at point: CGPoint) -> StampDrag? {
        guard let selection, let hit = firstHit(at: point),
              FloorPlan3DBuilder.selection(of: hit.entity) == selection,
              let entity = FloorPlan3DBuilder.selectableEntity(of: hit.entity) else { return nil }
        let wallId: String?
        switch selection {
        case .marker:
            wallId = nil
        case .wallFixture(let id):
            guard let fixture = planData.wallFixtures.first(where: { $0.id == id }) else { return nil }
            wallId = fixture.wallId
        case .doorWindow:
            return nil
        }
        guard let start = surfacePoint(at: point, wallId: wallId) else { return nil }
        return StampDrag(selection: selection, entity: entity, wallId: wallId, startPosition: entity.position, startSurfacePoint: start)
    }

    /// 화면 점 아래의 바닥 점, 콘센트면 붙은 벽의 면 점 (sceneRoot 기준). 스탬프 자신은 광선에서 뺀다
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
// 라벨처럼 고른 스탬프의 꼭대기를 화면 점으로 바꿔 위에 겹친다. 손잡이는 좌우로 끌면 돌고(사람·발화지점만), 메뉴는 그 오른쪽에 둔다
extension FloorPlan3DView {
    @ViewBuilder
    private var stampControls: some View {
        if let stampControlsPoint, let selection {
            if case .marker(let id) = selection {
                RotateHandleView()
                    .position(stampControlsPoint)
                    .gesture(rotateGesture(markerId: id))
            }
            if !isMovingStamp && !isRotating {
                StampEditMenuView(
                    onDuplicate: { onEdit(.duplicate(selection)) },
                    onDelete: { onEdit(.delete(selection)) }
                )
                .fixedSize()
                // 메뉴의 왼쪽 끝을 손잡이 오른쪽에 맞춘다
                .frame(width: 0, height: 0, alignment: .leading)
                .position(x: stampControlsPoint.x + Layout.editMenuLeading, y: stampControlsPoint.y)
            }
        }
    }

    private func rotateGesture(markerId: String) -> some Gesture {
        DragGesture()
            .updating($isRotating) { _, isRotating, _ in
                isRotating = true
            }
            .onChanged { value in
                selectedStampEntity?.orientation = PlanSpace.orientation(yaw: rotatedYaw(markerId: markerId, by: value.translation.width))
            }
            .onEnded { value in
                onEdit(.rotate(markerId: markerId, yaw: rotatedYaw(markerId: markerId, by: value.translation.width)))
            }
    }

    /// 손가락을 오른쪽으로 끈 만큼 시계 방향으로 더 돈 방향 (도)
    private func rotatedYaw(markerId: String, by distance: CGFloat) -> Double {
        let yaw = planData.markers.first { $0.id == markerId }?.yaw ?? 0
        return yaw + Double(distance) * Layout.degreesPerPoint
    }

    /// 고른 스탬프의 꼭대기 위에 손잡이·메뉴 자리를 잡는다. 카메라 뒤에 있으면 숨긴다
    private func updateStampControlsPoint(using content: RealityViewCameraContent) {
        var point: CGPoint?
        if let entity = selectedStampEntity {
            let bounds = entity.visualBounds(relativeTo: nil)
            let top = SIMD3(bounds.center.x, bounds.max.y, bounds.center.z)
            point = content.project(point: top, to: .local).map {
                CGPoint(x: $0.x, y: $0.y - Layout.rotateHandleGap)
            }
        }
        if point != stampControlsPoint {
            stampControlsPoint = point
        }
    }
}

// 확대 민감도
extension FloorPlan3DView {
    /// 기본 조작의 확대(카메라가 다가감)에 더해 도면 배율을 바꾼다.
    /// 손가락 벌린 비율이 m이면 기본 조작이 m만큼, 여기서 m^(extraZoomPower)만큼 더 키운다
    private var extraZoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                sceneRoot.scale = SIMD3(repeating: zoom(for: value.magnification))
            }
            .onEnded { value in
                committedZoom = zoom(for: value.magnification)
            }
    }

    private func zoom(for magnification: CGFloat) -> Float {
        let extra = pow(Float(magnification), Layout.extraZoomPower)
        return min(max(committedZoom * extra, Layout.zoomRange.lowerBound), Layout.zoomRange.upperBound)
    }
}

// 장면 만들기
extension FloorPlan3DView {
    private func rebuildScene() {
        sceneRoot.children.removeAll()
        sceneRoot.addChild(FloorPlan3DBuilder.makeScene(for: planData, selection: selection))
        switch selection {
        case .marker?, .wallFixture?:
            selectedStampEntity = selection.flatMap { FloorPlan3DBuilder.entity(for: $0, in: sceneRoot) }
        case .doorWindow?, nil:
            selectedStampEntity = nil
        }
    }

    /// 도면 앞쪽(도면 아래쪽) 위에서 비스듬히 내려다보는 카메라. 도면이 클수록 멀리 둔다
    private func makeCamera() -> PerspectiveCamera {
        let space = PlanSpace(plan: planData)
        let distance = Float(max(space.size.x, space.size.y, Layout.minimumViewSize)) * Layout.cameraDistanceRatio
        let camera = PerspectiveCamera()
        camera.look(at: .zero, from: normalize(Layout.cameraDirection) * distance, relativeTo: nil)
        return camera
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
        /// 기본 확대에 더하는 세기. 0이면 기본 그대로, 1이면 기본의 두 배(손가락을 2배 벌리면 4배 확대).
        /// 숫자를 올리면 더 민감해진다
        static let extraZoomPower: Float = 0.6
        /// 도면 배율을 이 범위 안에서만 바꾼다 (너무 작아지거나 화면을 넘지 않게)
        static let zoomRange: ClosedRange<Float> = 0.4...4
        /// 라벨 바로 앞(m)은 가림 판정에서 뺀다. 라벨 자리에 닿은 것을 벽으로 잘못 보지 않게
        static let labelHitMargin: Float = 0.05
        /// 라벨 위치·가림을 다시 계산하는 간격 (초)
        /// TEMP: 우선 여유 있게 잡은 값. 라벨을 아주 많이 띄워 보는 테스트를 하며 알맞은 값으로 조절할 예정
        static let labelUpdateInterval: TimeInterval = 1.0 / 60
        /// 스탬프 꼭대기와 회전 손잡이 가운데 사이 (pt)
        static let rotateHandleGap: CGFloat = 36
        /// 손잡이 가운데에서 편집 메뉴 왼쪽 끝까지 (pt). 손잡이(44pt) 오른쪽에 8pt 띄운다
        static let editMenuLeading: CGFloat = 30
        /// 회전 손잡이를 1pt 끌 때 도는 각도 (도)
        static let degreesPerPoint = 1.0
    }
}

#Preview {
    FloorPlan3DView(planData: DummyFloorPlan.planData, selection: nil, onTap: { _ in }, onEdit: { _ in })
}

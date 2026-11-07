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
            }
        }
        // TODO: 팀원이 만든 도면 미리보기에도 같은 회전·확대 조작이 있음. 나중에 하나로 통일할지 확인
        .realityViewCameraControls(.orbit)
        .simultaneousGesture(extraZoomGesture)
        .simultaneousGesture(tapGesture)
        .overlay(alignment: .topLeading) {
            roomLabels
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
        guard let cameraContent,
              let scene = sceneRoot.scene,
              let ray = cameraContent.ray(through: point, in: .local, to: .scene),
              let hit = scene.raycast(origin: ray.origin, direction: ray.direction, query: .nearest, relativeTo: nil).first
        else { return nil }
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
    }
}

#Preview {
    FloorPlan3DView(planData: DummyFloorPlan.planData, selection: nil, onTap: { _ in })
}

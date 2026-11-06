// 도면을 3D로 보여 주는 뷰. 한 손가락으로 돌리고, 두 손가락으로 확대·축소한다
//
// PoC는 ARView에 카메라 조종(SceneController)을 직접 만들었지만, 여기서는 SwiftUI RealityView와
// 애플 기본 카메라 조작(.realityViewCameraControls(.orbit))을 쓴다

import RealityKit
import SwiftUI

struct FloorPlan3DView: View {
    let planData: PlanData

    /// 도면 엔티티를 담는 자리. 도면이 바뀌면 이 안만 다시 만든다
    @State private var sceneRoot = Entity()

    var body: some View {
        RealityView { content in
            content.add(sceneRoot)
            content.add(makeLight())
            content.add(makeCamera())
        }
        .realityViewCameraControls(.orbit)
        .onChange(of: planData, initial: true) {
            rebuildScene()
        }
    }
}

// 장면 만들기
extension FloorPlan3DView {
    private func rebuildScene() {
        sceneRoot.children.removeAll()
        sceneRoot.addChild(FloorPlan3DBuilder.makeScene(for: planData))
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
    }
}

#Preview {
    FloorPlan3DView(planData: DummyFloorPlan.planData)
}

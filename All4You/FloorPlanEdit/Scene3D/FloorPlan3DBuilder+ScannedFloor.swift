// 3D에서 스캔한 바닥(PlanData.floors)을 그린다. 큰 바닥 판 바로 위에 바닥마다 얇은 판을 더한다.
// 오목한 다각형(ㄱ자 방 등)도 그릴 수 있게 귀 자르기(Floor.triangleIndices)로 삼각형을 나눈다. 충돌 모양은 넣지 않는다 (스탬프 놓기는 큰 바닥 판이 받는다)

import RealityKit
import UIKit

extension FloorPlan3DBuilder {
    /// 스캔한 바닥 판들을 담은 엔티티
    static func makeScannedFloors(_ floors: [Floor], space: PlanSpace) -> Entity {
        let group = Entity()
        for floor in floors {
            guard let mesh = scannedFloorMesh(floor, space: space) else { continue }
            group.addChild(ModelEntity(mesh: mesh, materials: [scannedFloorMaterial]))
        }
        return group
    }

    /// 바닥 하나의 판. 위에서도 아래에서도 보이게 두 방향 면을 모두 넣는다
    private static func scannedFloorMesh(_ floor: Floor, space: PlanSpace) -> MeshResource? {
        let triangles = floor.triangleIndices
        guard !triangles.isEmpty else { return nil }
        var descriptor = MeshDescriptor(name: "scannedFloor")
        descriptor.positions = MeshBuffer(floor.points.map { space.world($0, height: ScannedFloorModel.lift) })
        descriptor.normals = MeshBuffer(floor.points.map { _ in SIMD3<Float>(0, 1, 0) })
        var indices: [UInt32] = []
        for start in stride(from: 0, to: triangles.count, by: 3) {
            indices += [triangles[start], triangles[start + 1], triangles[start + 2]]
            indices += [triangles[start], triangles[start + 2], triangles[start + 1]]
        }
        descriptor.primitives = .triangles(indices)
        return try? MeshResource.generate(from: [descriptor])
    }

    /// 빛을 받지 않는 옅은 회색 반투명 판. 큰 바닥 판과 구분되고 벽·가구 아래에 깔린다
    // TEMP: 바닥 색과 높이는 Figma에 없어 임시로 정함
    private static var scannedFloorMaterial: UnlitMaterial {
        var material = UnlitMaterial(color: UIColor(resource: .gray300))
        material.blending = .transparent(opacity: .init(scale: ScannedFloorModel.opacity))
        return material
    }

    private enum ScannedFloorModel {
        /// 큰 바닥 판 위로 띄우는 높이 (m). 겹쳐 깜빡이지 않을 만큼만
        static let lift = 0.005
        static let opacity: Float = 0.7
    }
}

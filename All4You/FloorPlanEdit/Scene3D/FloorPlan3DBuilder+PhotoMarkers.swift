// 북마크 사진을 찍은 자리를 3D 도면에 구로, 바라본 쪽을 구에서 뻗는 원뿔로 그린다
// 2D의 번호 핀과 촬영 방향 부채꼴(BookmarkPhotoMarkerLayer)을 3D로 옮긴 것. 바닥에서 구까지 가는 기둥을 세워 어느 자리 위인지 보이게 한다

import RealityKit
import UIKit

extension FloorPlan3DBuilder {
    /// 사진 표시들을 모아 두는 엔티티 이름. 화면은 이 이름으로 찾아 사진 표시만 다시 만든다
    static let photoMarkersName = "photoMarkers"
    /// 사진 구의 충돌 그룹. 벽(1)·바닥(2)·가구(3)와 겹치지 않는 비트
    static let photoMarkerCollisionGroup = CollisionGroup(rawValue: 1 << 4)

    /// 사진마다 기둥과 구를 만들어 한 엔티티에 모은다
    static func makePhotoMarkers(_ markers: [Plan3DPhotoMarker], space: PlanSpace) -> Entity {
        PhotoMarkerComponent.registerComponent()
        let group = Entity()
        group.name = photoMarkersName
        for marker in markers {
            group.addChild(makePhotoMarker(marker, space: space))
        }
        return group
    }

    /// 눌린 엔티티가 사진 구면 그 사진 id, 아니면 nil
    static func photoID(of entity: Entity) -> UUID? {
        entity.components[PhotoMarkerComponent.self]?.photoID
    }

    /// 사진 하나의 표시. 엔티티 자리는 사진을 찍은 바닥 점이고, 구와 기둥은 그 위로 쌓는다
    // 충돌 모양은 구에만 붙인다. 전용 그룹이라 라벨 가림 판정(벽·바닥 그룹만 봄)에는 끼어들지 않고, 기둥·원뿔에는 붙이지 않는다
    private static func makePhotoMarker(_ marker: Plan3DPhotoMarker, space: PlanSpace) -> Entity {
        let root = Entity()
        root.name = marker.id.uuidString
        root.position = space.world(marker.placement.position)
        // 다른 사진을 골랐으면 기둥·구·원뿔을 함께 흐리게 한다 (자식에도 적용됨)
        if marker.isDimmed {
            root.components.set(OpacityComponent(opacity: PhotoMarkerModel.dimmedOpacity))
        }

        let sphereHeight = marker.sphereHeight
        let sphere = ModelEntity(
            mesh: .generateSphere(radius: PhotoMarkerModel.sphereRadius),
            materials: [PhotoMarkerModel.sphere]
        )
        sphere.position.y = sphereHeight
        // 누르기 판정은 보이는 구보다 크게 둬서 손가락으로 쉽게 맞게 한다
        sphere.components.set(CollisionComponent(
            shapes: [.generateSphere(radius: PhotoMarkerModel.tapRadius)],
            filter: CollisionFilter(group: photoMarkerCollisionGroup, mask: .all)
        ))
        sphere.components.set(PhotoMarkerComponent(photoID: marker.id))
        root.addChild(sphere)

        // 기둥은 바닥에서 구 아래까지. 구가 바닥 가까이 있어 길이가 없으면 그리지 않는다
        let columnHeight = sphereHeight - PhotoMarkerModel.sphereRadius
        if columnHeight > 0.01 {
            let column = ModelEntity(
                mesh: .generateCylinder(height: columnHeight, radius: PhotoMarkerModel.columnRadius),
                materials: [PhotoMarkerModel.column]
            )
            // 원기둥은 가운데가 기준이라 절반만큼 올려 바닥에 닿게 한다
            column.position.y = columnHeight / 2
            root.addChild(column)
        }

        if marker.showsDirection, let cone = makeDirectionCone(placement: marker.placement) {
            cone.position.y = sphereHeight
            root.addChild(cone)
        }
        return root
    }

    /// 구 가운데에서 바라본 쪽으로 벌어지는 원뿔. yaw·pitch가 모두 없거나 메시·재질을 못 만들면 nil (구만 그린다)
    private static func makeDirectionCone(placement: PhotoPlacement) -> ModelEntity? {
        guard placement.yaw != nil || placement.pitch != nil,
              let material = PhotoMarkerModel.coneMaterial,
              let mesh = try? makeConeMesh(fieldOfView: placement.fieldOfView) else { return nil }
        let cone = ModelEntity(mesh: mesh, materials: [material])
        // 좌우(yaw)로 먼저 돌리고 그 자리에서 위아래(pitch)로 든다. 엔티티의 -z가 바라보는 쪽이다.
        // x축으로 +θ 돌리면 -z가 위를 보므로 pitch(위가 +)를 그대로 쓴다. yaw가 없으면(수직으로 찍음) 0으로 둔다
        cone.orientation = PlanSpace.orientation(yaw: placement.yaw ?? 0)
            * simd_quatf(angle: Float((placement.pitch ?? 0) * .pi / 180), axis: [1, 0, 0])
        return cone
    }

    /// 꼭짓점(0, 0, 0)에서 -z 쪽으로 뻗는 원뿔 옆면. 밑면 뚜껑은 만들지 않는다 (끝이 투명하게 사라지는 2D 부채꼴과 같게)
    private static func makeConeMesh(fieldOfView: Double?) throws -> MeshResource {
        let length = PhotoMarkerModel.coneLength
        // 벌어진 각은 화각이고 90°를 넘기지 않는다. 밑면 반지름 = 길이 × tan(벌어진 각 / 2)
        let spread = min(fieldOfView ?? PhotoPlacement.defaultFieldOfView, PhotoMarkerModel.maxSpread)
        let radius = length * Float(tan(spread * .pi / 360))
        let count = PhotoMarkerModel.coneSegments

        // 0번 = 꼭짓점, 1...count번 = 밑면 원 위의 점
        var positions: [SIMD3<Float>] = [.zero]
        // 세로 방향 그라데이션 텍스처를 읽을 좌표. 꼭짓점 v = 1, 밑면 v = 0 (u는 아무 값).
        // 실기기에서 보니 v = 0이 이미지 아래쪽(투명한 쪽)이라 계획과 반대로 둔다
        var uvs: [SIMD2<Float>] = [[0, 1]]
        for step in 0..<count {
            let angle = Float(step) / Float(count) * 2 * .pi
            positions.append([radius * cos(angle), radius * sin(angle), -length])
            uvs.append([0, 0])
        }
        var indices: [UInt32] = []
        for step in 0..<count {
            // 삼각형 = (꼭짓점, 밑면 i번, 밑면 i+1번). 마지막은 처음 점으로 돌아온다
            indices += [0, UInt32(step + 1), UInt32((step + 1) % count + 1)]
        }

        var descriptor = MeshDescriptor(name: "photoDirectionCone")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(uvs)
        descriptor.primitives = .triangles(indices)
        return try MeshResource.generate(from: [descriptor])
    }
}

/// 구 엔티티가 어느 사진의 것인지 적어 두는 표시. 구를 눌렀을 때 사진을 찾는 데 쓴다
struct PhotoMarkerComponent: Component {
    let photoID: UUID
}

// 크기·재질 (색은 디자인 시스템 ColorSystem)
@MainActor
private enum PhotoMarkerModel {
    /// 구 반지름 (m)
    // TEMP: 실기기에서 보고 조절
    static let sphereRadius: Float = 0.12
    /// 구를 누를 수 있는 범위 반지름 (m). 보이는 구(0.12)보다 크게
    // TEMP: 실기기에서 눌러 보고 조절
    static let tapRadius: Float = 0.15
    /// 바닥까지 내려가는 기둥 반지름 (m)
    // TEMP: 실기기에서 보고 조절
    static let columnRadius: Float = 0.01
    /// 스탬프 재질(Materials.stamp)과 같은 값. Materials가 다른 파일의 private이라 따로 둔다
    static let sphere = SimpleMaterial(color: UIColor(resource: .brand500), roughness: 0.6, isMetallic: false)
    static let column = UnlitMaterial(color: UIColor(resource: .gray300))

    /// 원뿔 길이 (m). 2D 부채꼴은 0.5m지만 3D에서는 구에 묻혀 짧아 보여 0.8m로 시작한다
    // TEMP: 실기기에서 보고 조절
    static let coneLength: Float = 0.8
    /// 원뿔이 벌어질 수 있는 가장 큰 각 (도). 2D 부채꼴과 같다
    static let maxSpread = 90.0
    /// 원뿔 밑면을 나누는 점 수. 많을수록 둥글다
    static let coneSegments = 24
    /// 다른 사진을 골랐을 때 흐린 정도. 2D 번호 핀(dimmedOpacity)과 같다
    static let dimmedOpacity: Float = 0.3
    /// 원뿔 구 쪽의 진하기. 2D 부채꼴(0.45)보다 진하게 둔다
    // TEMP: 실기기에서 보고 더 진하게 하자고 해서 0.65로 올림. 더 보고 조절
    static let coneStartOpacity: CGFloat = 1
    /// 그라데이션 이미지의 세로 칸 수
    static let gradientRows = 64

    /// 구 쪽(위)은 brand500 알파 coneStartOpacity에서 끝(아래)은 0으로 옅어지는 반투명 재질. 한 번만 만들어 모든 원뿔이 나눠 쓴다.
    /// 텍스처나 재질을 못 만들면 nil이고, 그러면 원뿔만 빼고 구는 그린다
    static let coneMaterial: UnlitMaterial? = {
        guard let image = makeGradientImage(),
              let texture = try? TextureResource(image: image, options: .init(semantic: .color)) else { return nil }
        var material = UnlitMaterial()
        material.color = .init(tint: .white, texture: .init(texture))
        material.blending = .transparent(opacity: .init(scale: 1))
        // 원뿔 안쪽 면도 보이게
        material.faceCulling = .none
        return material
    }()

    /// 폭 1칸, 높이 gradientRows칸. 첫 줄(위)이 가장 진하고 마지막 줄(아래)이 투명하다. 텍스처 좌표 v는 아래가 0이다
    private static func makeGradientImage() -> CGImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: gradientRows), format: format)
        let image = renderer.image { context in
            let color = UIColor(resource: .brand500)
            for row in 0..<gradientRows {
                let fade = 1 - CGFloat(row) / CGFloat(gradientRows - 1)
                color.withAlphaComponent(coneStartOpacity * fade).setFill()
                context.fill(CGRect(x: 0, y: row, width: 1, height: 1))
            }
        }
        return image.cgImage
    }
}

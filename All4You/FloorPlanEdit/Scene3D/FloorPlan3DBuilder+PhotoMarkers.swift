// 북마크 사진을 찍은 자리를 3D 도면에 그린다: 바닥 원판, 바닥에서 올라오는 기둥, 카메라 높이의 작은 구, 바라본 쪽으로 벌어지는 사각뿔
// PoC 앱(FloorPlanEditPoC)의 사진 표시를 옮겼다. 다른 점은 카메라 상자를 작은 구로 바꾸고, 시야를 접었을 때 앞에 붙던 원뿔과 모서리 선을 뺀 것.
// 사각뿔은 구 쪽이 진하고 끝으로 갈수록 투명해진다

import RealityKit
import UIKit

extension FloorPlan3DBuilder {
    /// 사진 표시들을 모아 두는 엔티티 이름. 화면은 이 이름으로 찾아 사진 표시만 다시 만든다
    static let photoMarkersName = "photoMarkers"
    /// 사진 구의 충돌 그룹. 벽(1)·바닥(2)·가구(3)와 겹치지 않는 비트
    static let photoMarkerCollisionGroup = CollisionGroup(rawValue: 1 << 4)

    /// 사진마다 원판·기둥·구(·사각뿔)를 만들어 한 엔티티에 모은다
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

    /// 사진 하나의 표시. 엔티티 자리는 사진을 찍은 바닥 점이고, 나머지는 그 위로 쌓는다
    // 충돌 모양은 구에만 붙인다. 전용 그룹이라 라벨 가림 판정(벽·바닥 그룹만 봄)에는 끼어들지 않는다
    private static func makePhotoMarker(_ marker: Plan3DPhotoMarker, space: PlanSpace) -> Entity {
        let root = Entity()
        root.name = marker.id.uuidString
        root.position = space.world(marker.placement.position)
        // 다른 사진을 골랐으면 모두 함께 흐리게 한다 (자식에도 적용됨)
        if marker.isDimmed {
            root.components.set(OpacityComponent(opacity: PhotoMarkerModel.dimmedOpacity))
        }

        // 바닥 원판. 위에서 볼 때 어느 자리인지 보인다
        let disk = ModelEntity(
            mesh: .generateCylinder(height: PhotoMarkerModel.diskHeight, radius: PhotoMarkerModel.diskRadius),
            materials: [PhotoMarkerModel.tintUnlit]
        )
        // 바닥과 겹쳐 깜박이지 않게 조금 띄운다
        disk.position.y = PhotoMarkerModel.diskLift
        root.addChild(disk)

        // 기둥은 바닥에서 카메라 높이까지. 원기둥은 가운데가 기준이라 절반만큼 올려 바닥에 닿게 한다
        let height = marker.sphereHeight
        let pole = ModelEntity(
            mesh: .generateCylinder(height: height, radius: PhotoMarkerModel.poleRadius),
            materials: [PhotoMarkerModel.pole]
        )
        pole.position.y = height / 2
        root.addChild(pole)

        // 카메라 자리. 구와 시야 사각뿔이 이 엔티티를 기준으로 돈다
        let camera = Entity()
        camera.position.y = height
        // 좌우(yaw)로 먼저 돌리고 그 자리에서 위아래(pitch)로 든다. 엔티티의 -z가 바라보는 쪽이다.
        // x축으로 +θ 돌리면 -z가 위를 보므로 pitch(위가 +)를 그대로 쓴다. yaw가 없으면(수직으로 찍음) 0으로 둔다
        camera.orientation = PlanSpace.orientation(yaw: marker.placement.yaw ?? 0)
            * simd_quatf(angle: Float((marker.placement.pitch ?? 0) * .pi / 180), axis: [1, 0, 0])
        root.addChild(camera)

        let head = ModelEntity(mesh: .generateSphere(radius: PhotoMarkerModel.headRadius), materials: [PhotoMarkerModel.head])
        // 누르기 판정은 보이는 구보다 크게 둬서 손가락으로 쉽게 맞게 한다
        head.components.set(CollisionComponent(
            shapes: [.generateSphere(radius: PhotoMarkerModel.tapRadius)],
            filter: CollisionFilter(group: photoMarkerCollisionGroup, mask: .all)
        ))
        head.components.set(PhotoMarkerComponent(photoID: marker.id))
        camera.addChild(head)

        if marker.showsDirection, marker.placement.yaw != nil || marker.placement.pitch != nil {
            addViewFrustum(to: camera, fieldOfView: marker.placement.fieldOfView)
        }
        return root
    }

    /// 카메라에서 -z 쪽으로 벌어지는 사각뿔. 테두리 선은 없고 구 쪽이 진하게 끝으로 옅어진다. 메시·재질을 못 만들면 그리지 않는다 (구만 남는다)
    private static func addViewFrustum(to camera: Entity, fieldOfView: Double?) {
        guard let material = PhotoMarkerModel.frustum else { return }
        let corners = frustumCorners(fieldOfView: fieldOfView)

        // 꼭짓점(0번) 하나와 밑면 네 점(1~4번). 삼각형 = (꼭짓점, 밑면 i번, 밑면 i+1번). 밑면 뚜껑은 만들지 않는다
        var indices: [UInt32] = []
        for index in 0..<4 {
            indices += [0, UInt32(1 + index), UInt32(1 + (index + 1) % 4)]
        }
        var descriptor = MeshDescriptor(name: "photoViewFrustum")
        descriptor.positions = MeshBuffers.Positions([.zero] + corners)
        // 세로 그라데이션 텍스처를 읽을 좌표. 꼭짓점 v = 1(이미지 맨 위, 진함), 밑면 v = 0(이미지 맨 아래, 투명). u는 아무 값
        descriptor.textureCoordinates = MeshBuffers.TextureCoordinates([[0, 1], [0, 0], [0, 0], [0, 0], [0, 0]])
        descriptor.primitives = .triangles(indices)
        guard let mesh = try? MeshResource.generate(from: [descriptor]) else { return }
        camera.addChild(ModelEntity(mesh: mesh, materials: [material]))
    }

    /// 사각뿔 밑면의 네 점 (왼쪽 위, 오른쪽 위, 오른쪽 아래, 왼쪽 아래). 가로 화각은 사진 값, 세로 화각은 4:3 사진으로 보고 계산한다
    // TEMP: PhotoPlacement에 세로 화각·사진 방향(가로·세로)이 없어 4:3 가로 사진으로 가정한다. 데이터에 들어오면 그 값으로 바꾼다
    private static func frustumCorners(fieldOfView: Double?) -> [SIMD3<Float>] {
        // 벌어진 각이 너무 커지지 않게 2D 부채꼴과 같은 한계를 둔다
        let horizontal = min(fieldOfView ?? PhotoPlacement.defaultFieldOfView, PhotoMarkerModel.maxSpread) * .pi / 180
        let length = PhotoMarkerModel.frustumLength
        let halfWidth = Float(tan(horizontal / 2)) * length
        // 세로 반쪽 = 가로 반쪽 ÷ (가로÷세로 비율)
        let halfHeight = halfWidth / PhotoMarkerModel.imageAspect
        return [
            [-halfWidth, halfHeight, -length],
            [halfWidth, halfHeight, -length],
            [halfWidth, -halfHeight, -length],
            [-halfWidth, -halfHeight, -length]
        ]
    }
}

/// 구 엔티티가 어느 사진의 것인지 적어 두는 표시. 구를 눌렀을 때 사진을 찾는 데 쓴다
struct PhotoMarkerComponent: Component {
    let photoID: UUID
}

// 크기·재질 (색은 디자인 시스템 ColorSystem). 값은 PoC의 사진 표시와 같게 시작한다
@MainActor
private enum PhotoMarkerModel {
    /// 카메라 자리 구 반지름 (m). PoC의 카메라 상자(0.12 × 0.08 × 0.05)보다 작게
    // TEMP: 실기기에서 보고 조절
    static let headRadius: Float = 0.05
    /// 구를 누를 수 있는 범위 반지름 (m). 보이는 구보다 크게
    // TEMP: 실기기에서 눌러 보고 조절
    static let tapRadius: Float = 0.25
    /// 바닥 원판 반지름·두께·띄우는 높이 (m)
    static let diskRadius: Float = 0.12
    static let diskHeight: Float = 0.01
    static let diskLift: Float = 0.02
    /// 기둥 반지름 (m). PoC(0.012)보다 얇게
    // TEMP: 실기기에서 보고 조절
    static let poleRadius: Float = 0.003
    /// 사각뿔 길이 (m)
    // TEMP: 실기기에서 보고 조절
    static let frustumLength: Float = 1.2
    /// 사각뿔 구 쪽의 진하기. 끝은 0이다
    // TEMP: 실기기에서 보고 조절
    static let frustumStartOpacity: CGFloat = 1
    /// 그라데이션 이미지의 세로 칸 수
    static let gradientRows = 64
    /// 사각뿔이 벌어질 수 있는 가장 큰 가로 각 (도). 2D 부채꼴과 같다
    static let maxSpread = 90.0
    /// 사진 가로÷세로 비율. 세로 화각을 계산할 때 쓴다
    static let imageAspect: Float = 4.0 / 3
    /// 다른 사진을 골랐을 때 흐린 정도. 2D 번호 핀(dimmedOpacity)과 같다
    static let dimmedOpacity: Float = 0.3

    /// 사진 방향과 관련된 부분(원판·구·사각뿔)의 색
    static let tint = UIColor(resource: .orange400)
    static let tintUnlit = UnlitMaterial(color: tint)
    static let head = SimpleMaterial(color: tint, roughness: 0.6, isMetallic: false)
    static let pole = SimpleMaterial(color: UIColor(resource: .gray500), roughness: 0.6, isMetallic: false)
    /// 구 쪽(위)은 진하고 끝(아래)은 투명해지는 사각뿔 재질. 한 번만 만들어 모든 사진이 나눠 쓴다.
    /// 텍스처를 못 만들면 nil이고, 그러면 사각뿔만 빼고 구는 그린다
    static let frustum: UnlitMaterial? = {
        guard let image = makeGradientImage(),
              let texture = try? TextureResource(image: image, options: .init(semantic: .color)) else { return nil }
        var material = UnlitMaterial()
        material.color = .init(tint: .white, texture: .init(texture))
        material.blending = .transparent(opacity: .init(scale: 1))
        // 사각뿔 안쪽 면도 보이게
        material.faceCulling = .none
        return material
    }()

    /// 폭 1칸, 높이 gradientRows칸. 첫 줄(위)이 가장 진하고 마지막 줄(아래)이 투명하다. 텍스처 좌표 v는 아래가 0이다
    private static func makeGradientImage() -> CGImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: gradientRows), format: format)
        let image = renderer.image { context in
            for row in 0..<gradientRows {
                let fade = 1 - CGFloat(row) / CGFloat(gradientRows - 1)
                tint.withAlphaComponent(frustumStartOpacity * fade).setFill()
                context.fill(CGRect(x: 0, y: row, width: 1, height: 1))
            }
        }
        return image.cgImage
    }
}

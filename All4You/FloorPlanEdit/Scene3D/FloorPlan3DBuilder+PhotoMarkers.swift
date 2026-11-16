// 북마크 사진을 찍은 자리를 3D 도면에 구로 그린다
// 2D의 번호 핀(BookmarkPhotoMarkerLayer)을 3D로 옮긴 것. 바닥에서 구까지 가는 기둥을 세워 어느 자리 위인지 보이게 한다

import RealityKit
import UIKit

extension FloorPlan3DBuilder {
    /// 사진 표시들을 모아 두는 엔티티 이름. 화면은 이 이름으로 찾아 사진 표시만 다시 만든다
    static let photoMarkersName = "photoMarkers"

    /// 사진마다 기둥과 구를 만들어 한 엔티티에 모은다
    static func makePhotoMarkers(_ markers: [Plan3DPhotoMarker], space: PlanSpace) -> Entity {
        let group = Entity()
        group.name = photoMarkersName
        for marker in markers {
            group.addChild(makePhotoMarker(marker, space: space))
        }
        return group
    }

    /// 사진 하나의 표시. 엔티티 자리는 사진을 찍은 바닥 점이고, 구와 기둥은 그 위로 쌓는다
    // 충돌 모양은 붙이지 않는다. 붙이면 3D 화면의 누르기와 라벨 가림 판정에 끼어든다
    private static func makePhotoMarker(_ marker: Plan3DPhotoMarker, space: PlanSpace) -> Entity {
        let root = Entity()
        root.name = marker.id.uuidString
        root.position = space.world(marker.placement.position)

        let sphereHeight = marker.sphereHeight
        let sphere = ModelEntity(
            mesh: .generateSphere(radius: PhotoMarkerModel.sphereRadius),
            materials: [PhotoMarkerModel.sphere]
        )
        sphere.position.y = sphereHeight
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
        return root
    }
}

// 크기·재질 (색은 디자인 시스템 ColorSystem)
@MainActor
private enum PhotoMarkerModel {
    /// 구 반지름 (m)
    // TEMP: 실기기에서 보고 조절
    static let sphereRadius: Float = 0.12
    /// 바닥까지 내려가는 기둥 반지름 (m)
    // TEMP: 실기기에서 보고 조절
    static let columnRadius: Float = 0.01
    /// 스탬프 재질(Materials.stamp)과 같은 값. Materials가 다른 파일의 private이라 따로 둔다
    static let sphere = SimpleMaterial(color: UIColor(resource: .brand500), roughness: 0.6, isMetallic: false)
    static let column = UnlitMaterial(color: UIColor(resource: .gray300))
}

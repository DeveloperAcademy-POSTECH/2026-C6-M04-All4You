// 도면(PlanData)을 RealityKit 3D 엔티티로 만든다. 도면이 바뀌면 통째로 다시 만든다
// 문 자리는 뚫어만 두고 문짝은 그리지 않는다
//
// 3D 좌표 (PlanSpace): 도면 (x, y) → 3D (x, 높이, y). 3D는 +y가 위, 도면 아래쪽이 +z.
// 도면 가운데를 3D 원점에 둬서, 카메라가 원점을 보고 돌면 도면 가운데를 중심으로 돈다

import RealityKit
import UIKit

@MainActor
enum FloorPlan3DBuilder {
    /// 도면 전체(바닥·벽·문창문·콘센트·표시)를 담은 엔티티 하나. selection과 같은 요소는 고른 표시로 그린다
    static func makeScene(for plan: PlanData, selection: PlanSelection?) -> Entity {
        PlanSelectionComponent.registerComponent()
        PlanWallComponent.registerComponent()
        let space = PlanSpace(plan: plan)
        let root = Entity()
        root.addChild(makeFloor(space: space))
        for wall in plan.walls where !wall.isVirtual {
            guard let line = plan.line(of: wall) else { continue }
            let openings = plan.doorWindows.filter { $0.wallId == wall.id }
            root.addChild(makeWall(wall, line: line, openings: openings, space: space, selection: selection))
        }
        for fixture in plan.wallFixtures {
            guard let wall = plan.wall(id: fixture.wallId), let line = plan.line(of: wall) else { continue }
            root.addChild(makeOutlet(fixture, wall: wall, line: line, space: space, selection: selection))
        }
        for marker in plan.markers {
            root.addChild(makeMarker(marker, space: space, selection: selection))
        }
        root.addChild(makeRoomLabelAnchors(for: plan.rooms, space: space))
        return root
    }
}

// 눌러 고르기
// 고를 수 있는 엔티티(스탬프·콘센트·창문 유리)에 PlanSelectionComponent를 붙이고, 광선이 맞은 엔티티에서 부모 쪽으로 올라가며 찾는다
extension FloorPlan3DBuilder {
    /// 벽 상자의 충돌 그룹. 라벨 가림 판정은 이 그룹만 본다 (스탬프·유리는 라벨을 가리지 않게)
    static let wallCollisionGroup = CollisionGroup(rawValue: 1 << 1)
    /// 바닥의 충돌 그룹. 스탬프를 끌 때 스탬프 자신은 빼고 바닥만 맞히려고 쓴다
    static let floorCollisionGroup = CollisionGroup(rawValue: 1 << 2)

    /// 광선이 맞은 엔티티가 어느 도면 요소인지. 모델의 일부(사람 머리 등)가 맞아도 부모로 올라가 찾는다
    static func selection(of entity: Entity) -> PlanSelection? {
        nearest(PlanSelectionComponent.self, from: entity)?.selection
    }

    /// 광선이 맞은 엔티티가 속한 도면 요소 엔티티 전체 (사람 머리가 맞으면 사람 전체). 끌어 옮길 때 이것을 움직인다
    static func selectableEntity(of entity: Entity) -> Entity? {
        sequence(first: entity, next: \.parent).first { $0.components.has(PlanSelectionComponent.self) }
    }

    /// root 아래에서 selection에 해당하는 엔티티를 찾는다
    static func entity(for selection: PlanSelection, in root: Entity) -> Entity? {
        if root.components[PlanSelectionComponent.self]?.selection == selection {
            return root
        }
        for child in root.children {
            if let found = entity(for: selection, in: child) {
                return found
            }
        }
        return nil
    }

    /// 광선이 맞은 엔티티가 벽 상자면 그 벽의 id (Wall.id)
    static func wallId(of entity: Entity) -> String? {
        nearest(PlanWallComponent.self, from: entity)?.wallId
    }

    /// entity부터 부모 쪽으로 올라가며 처음 만나는 컴포넌트
    private static func nearest<C: Component>(_ type: C.Type, from entity: Entity) -> C? {
        sequence(first: entity, next: \.parent)
            .lazy
            .compactMap { $0.components[type] }
            .first
    }

    /// 스탬프·콘센트에 고를 수 있는 표시와 충돌 모양(광선이 맞는 틀)을 붙인다
    private static func makeSelectable(_ entity: Entity, as selection: PlanSelection) {
        entity.components.set(PlanSelectionComponent(selection: selection))
        entity.generateCollisionShapes(recursive: true)
    }
}

/// 3D 엔티티가 어느 도면 요소인지 적어 두는 표시
struct PlanSelectionComponent: Component {
    let selection: PlanSelection
}

/// 벽 엔티티가 어느 벽인지 적어 두는 표시. 벽을 눌러 콘센트를 붙일 때 쓴다
struct PlanWallComponent: Component {
    let wallId: String
}

// 공간 이름 라벨 자리
extension FloorPlan3DBuilder {
    /// 라벨 자리들을 모아 두는 엔티티 이름. 화면은 이 이름으로 찾아 라벨을 겹친다
    static let roomLabelAnchorsName = "roomLabelAnchors"
    /// 라벨을 띄울 높이 (m). 벽(2.4m)보다 낮게 방 안에 둬서, 옆에서 보면 벽에 가려지고 위에서 보면 보이게(추후 수정 가능)
    private static let roomLabelHeight = 1.5

    /// 방마다 이름 라벨이 놓일 3D 점. 보이는 모양은 없고 위치만 있다. 엔티티 이름 = Room.id
    private static func makeRoomLabelAnchors(for rooms: [Room], space: PlanSpace) -> Entity {
        let group = Entity()
        group.name = roomLabelAnchorsName
        for room in rooms {
            let anchor = Entity()
            anchor.name = room.id
            anchor.position = space.world(SIMD2(room.labelX, room.labelY), height: roomLabelHeight)
            group.addChild(anchor)
        }
        return group
    }
}

/// 도면 좌표(m) ↔ 3D 좌표 변환
struct PlanSpace {
    /// 도면 가운데 (도면 좌표, m)
    let center: SIMD2<Double>
    /// 꼭짓점을 모두 감싸는 가로·세로 (m)
    let size: SIMD2<Double>

    init(plan: PlanData) {
        let xs = plan.vertices.map(\.x)
        let ys = plan.vertices.map(\.y)
        let minPoint = SIMD2(xs.min() ?? 0, ys.min() ?? 0)
        let maxPoint = SIMD2(xs.max() ?? 0, ys.max() ?? 0)
        center = (minPoint + maxPoint) / 2
        size = maxPoint - minPoint
    }

    /// 도면 점 p를 바닥에서 height(m) 위의 3D 점으로
    func world(_ p: SIMD2<Double>, height: Double = 0) -> SIMD3<Float> {
        SIMD3(Float(p.x - center.x), Float(height), Float(p.y - center.y))
    }

    /// 3D 점을 도면 점으로 (world의 반대). 높이는 버린다
    func plan(_ p: SIMD3<Float>) -> SIMD2<Double> {
        SIMD2(Double(p.x) + center.x, Double(p.z) + center.y)
    }

    /// 엔티티의 +x 축이 도면 방향 direction을 향하게 하는 회전 (위아래 축 기준)
    static func orientation(along direction: SIMD2<Double>) -> simd_quatf {
        simd_quatf(angle: Float(atan2(-direction.y, direction.x)), axis: [0, 1, 0])
    }

    /// 사람·발화지점의 방향 yaw(도)를 회전으로. yaw는 도면 위쪽 0°에서 시계 방향이라, 위에서 볼 때 시계 방향 = 위아래 축 기준 음의 회전
    static func orientation(yaw: Double) -> simd_quatf {
        simd_quatf(angle: Float(-yaw * .pi / 180), axis: [0, 1, 0])
    }
}

// 바닥
extension FloorPlan3DBuilder {
    /// 도면보다 사방 1m 넓은 바닥. 눌러서 스탬프를 놓을 수 있게 아래로 얇은 충돌 상자를 붙인다
    private static func makeFloor(space: PlanSpace) -> ModelEntity {
        let margin = 1.0
        let width = Float(space.size.x + margin * 2)
        let depth = Float(space.size.y + margin * 2)
        let thickness: Float = 0.01
        let floor = ModelEntity(mesh: .generatePlane(width: width, depth: depth), materials: [Materials.floor])
        let shape = ShapeResource.generateBox(width: width, height: thickness, depth: depth)
            .offsetBy(translation: [0, -thickness / 2, 0])
        floor.components.set(CollisionComponent(shapes: [shape], filter: CollisionFilter(group: floorCollisionGroup, mask: .all)))
        return floor
    }
}

// 벽과 문·창문
extension FloorPlan3DBuilder {
    /// 벽을 따라 자른 한 토막. opening이 nil이면 막힌 벽, 있으면 문·창문 자리
    private struct WallPiece {
        let from: Double
        let to: Double
        let opening: DoorWindow?
    }

    /// 벽 하나. 벽 엔티티 안에서는 +x = 벽 시작점에서 벽을 따라간 거리, +y = 위
    private static func makeWall(_ wall: Wall, line: WallLine, openings: [DoorWindow], space: PlanSpace, selection: PlanSelection?) -> Entity {
        let entity = Entity()
        entity.components.set(PlanWallComponent(wallId: wall.id))
        entity.position = space.world(line.start)
        entity.orientation = PlanSpace.orientation(along: line.direction)
        let pieces = wallPieces(length: line.length, thickness: wall.thickness, openings: openings)
        for piece in pieces {
            boxes(for: piece, wall: wall, selection: selection).forEach { entity.addChild($0) }
        }
        return entity
    }

    /// 벽을 문·창문 자리 기준으로 자른다. 모서리가 비지 않게 양 끝을 두께 절반씩 늘린다
    private static func wallPieces(length: Double, thickness: Double, openings: [DoorWindow]) -> [WallPiece] {
        var pieces: [WallPiece] = []
        var cursor = -thickness / 2
        let end = length + thickness / 2
        for opening in openings.sorted(by: { $0.centerAlongWall < $1.centerAlongWall }) {
            let from = max(opening.centerAlongWall - opening.width / 2, cursor)
            let to = min(opening.centerAlongWall + opening.width / 2, end)
            guard to > from else { continue }
            pieces.append(WallPiece(from: cursor, to: from, opening: nil))
            pieces.append(WallPiece(from: from, to: to, opening: opening))
            cursor = to
        }
        pieces.append(WallPiece(from: cursor, to: end, opening: nil))
        return pieces
    }

    /// 토막 하나를 상자로. 문·개구부는 위쪽만, 창문은 위·아래 벽과 유리
    private static func boxes(for piece: WallPiece, wall: Wall, selection: PlanSelection?) -> [ModelEntity] {
        guard let opening = piece.opening else {
            return [wallBox(piece, bottom: 0, top: wall.height, depth: wall.thickness)].compactMap { $0 }
        }
        let top = min(opening.sillHeight + opening.height, wall.height)
        var result = [wallBox(piece, bottom: top, top: wall.height, depth: wall.thickness)]
        if opening.kind == .window {
            result.append(wallBox(piece, bottom: 0, top: opening.sillHeight, depth: wall.thickness))
            result.append(windowGlass(piece, bottom: opening.sillHeight, top: top, window: opening, selection: selection))
        }
        return result.compactMap { $0 }
    }

    /// 벽 상자. 벽 충돌 그룹이라 광선이 부딪힌다 (벽 뒤 라벨은 숨고, 벽 뒤 스탬프는 못 고름)
    private static func wallBox(_ piece: WallPiece, bottom: Double, top: Double, depth: Double) -> ModelEntity? {
        let filter = CollisionFilter(group: wallCollisionGroup, mask: .all)
        return box(piece, bottom: bottom, top: top, depth: depth, material: Materials.wall, filter: filter)
    }

    /// 창문 유리. 눌러 고를 수 있고, 벽 그룹이 아니라 창 너머 라벨은 가리지 않는다
    private static func windowGlass(_ piece: WallPiece, bottom: Double, top: Double, window: DoorWindow, selection: PlanSelection?) -> ModelEntity? {
        let tag = PlanSelection.doorWindow(window.id)
        let material = tag == selection ? Materials.selectedGlass : Materials.glass
        let glass = box(piece, bottom: bottom, top: top, depth: 0.03, material: material, filter: .default)
        glass?.components.set(PlanSelectionComponent(selection: tag))
        return glass
    }

    /// 토막 구간에 bottom~top 높이의 상자와 같은 크기의 충돌 모양. 너무 얇으면 만들지 않는다.
    /// TEMP: 잔선(아주 얇은 조각) 처리는 임시로 해 둔 것. 실제 도면을 여러 개 변환해 보고,
    /// 이후 이슈에서 편집 기능을 다루면서 필요하면 바꾸거나 지울 수 있다
    private static func box(_ piece: WallPiece, bottom: Double, top: Double, depth: Double, material: any Material, filter: CollisionFilter) -> ModelEntity? {
        let width = piece.to - piece.from
        let height = top - bottom
        guard width > 0.001, height > 0.001 else { return nil }
        let size = SIMD3(Float(width), Float(height), Float(depth))
        let entity = ModelEntity(mesh: .generateBox(size: size), materials: [material])
        entity.components.set(CollisionComponent(shapes: [.generateBox(size: size)], filter: filter))
        entity.position = [Float((piece.from + piece.to) / 2), Float((bottom + top) / 2), 0]
        return entity
    }
}

// 콘센트와 표시
// TEMP: 콘센트·사람·발화지점은 RealityKit 기본 도형으로 만든 임시 모양. 디자인의 3D 아이콘 에셋이 생기면 바꿈
extension FloorPlan3DBuilder {
    /// 벽 면에 붙은 콘센트
    private static func makeOutlet(_ fixture: WallFixture, wall: Wall, line: WallLine, space: PlanSpace, selection: PlanSelection?) -> ModelEntity {
        let tag = PlanSelection.wallFixture(fixture.id)
        let size = SIMD3<Float>(0.2, 0.2, 0.04)
        let normal = fixture.face == .left ? line.leftNormal : -line.leftNormal
        let offset = wall.thickness / 2 + Double(size.z) / 2
        let point = line.point(along: fixture.positionAlongWall) + normal * offset
        let entity = ModelEntity(mesh: .generateBox(size: size, cornerRadius: 0.02), materials: [stampMaterial(tag, selection: selection)])
        entity.position = space.world(point, height: fixture.heightFromFloor)
        entity.orientation = PlanSpace.orientation(along: line.direction)
        makeSelectable(entity, as: tag)
        return entity
    }

    /// 사람·발화지점
    private static func makeMarker(_ marker: PlanMarker, space: PlanSpace, selection: PlanSelection?) -> Entity {
        let tag = PlanSelection.marker(marker.id)
        let material = stampMaterial(tag, selection: selection)
        let entity = marker.kind == .person ? personModel(lying: marker.lying ?? false, material: material) : flameModel(material: material)
        entity.position = space.world(marker.position, height: marker.height)
        entity.orientation = PlanSpace.orientation(yaw: marker.yaw)
        makeSelectable(entity, as: tag)
        return entity
    }

    /// 고른 스탬프는 다른 색으로
    private static func stampMaterial(_ tag: PlanSelection, selection: PlanSelection?) -> SimpleMaterial {
        tag == selection ? Materials.selectedStamp : Materials.stamp
    }

    /// 몸통과 머리. 누우면 머리가 바라보는 방향(-z)으로 눕는다
    private static func personModel(lying: Bool, material: SimpleMaterial) -> Entity {
        let body = Entity()
        let torso = ModelEntity(mesh: .generateBox(width: 0.4, height: 1.2, depth: 0.25, cornerRadius: 0.1), materials: [material])
        torso.position = [0, 0.6, 0]
        let head = ModelEntity(mesh: .generateSphere(radius: 0.13), materials: [material])
        head.position = [0, 1.35, 0]
        body.addChild(torso)
        body.addChild(head)
        if lying {
            body.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
            body.position = [0, 0.13, 0]
        }
        let wrapper = Entity()
        wrapper.addChild(body)
        return wrapper
    }

    /// 불꽃 대신 원뿔
    private static func flameModel(material: SimpleMaterial) -> Entity {
        let cone = ModelEntity(mesh: .generateCone(height: 0.5, radius: 0.18), materials: [material])
        cone.position = [0, 0.25, 0]
        let wrapper = Entity()
        wrapper.addChild(cone)
        return wrapper
    }
}

// 재질 (색은 디자인 시스템 ColorSystem)
@MainActor
private enum Materials {
    static let floor = UnlitMaterial(color: UIColor(resource: .gray50))
    static let wall = SimpleMaterial(color: UIColor(resource: .white), roughness: 0.85, isMetallic: false)
    static let stamp = SimpleMaterial(color: UIColor(resource: .brand500), roughness: 0.6, isMetallic: false)
    static let glass = glass(tint: UIColor(resource: .gray200), opacity: 0.35)
    // TEMP: 고른 표시 모양은 Figma에서 확인 전이라 임시로 진한 주황
    static let selectedStamp = SimpleMaterial(color: UIColor(resource: .orange700), roughness: 0.6, isMetallic: false)
    static let selectedGlass = glass(tint: UIColor(resource: .brand500), opacity: 0.6)

    private static func glass(tint: UIColor, opacity: Float) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: tint)
        material.blending = .transparent(opacity: .init(scale: opacity))
        return material
    }
}

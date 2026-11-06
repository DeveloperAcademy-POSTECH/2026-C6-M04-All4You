// 도면(PlanData)을 RealityKit 3D 엔티티로 만든다
//
// FloorPlanEditPoC의 SceneBuilder에서 바닥·벽·창문·콘센트 만들기를 가져와 단순하게 옮겼다.
// PoC에서 뺀 것: 바뀐 것만 다시 만들기(지금은 도면이 바뀌면 통째로 다시 만듦), 고른 표시와 탭 판정(이슈 20-1),
// 문짝(열리는 방향이 ERD에 없어 문 자리는 뚫어만 둠), 가구, 사진, 2D↔3D 전환
//
// 3D 좌표 (PlanSpace): 도면 (x, y) → 3D (x, 높이, y). 3D는 +y가 위, 도면 아래쪽이 +z.
// 도면 가운데를 3D 원점에 둬서, 카메라가 원점을 보고 돌면 도면 가운데를 중심으로 돈다

import RealityKit
import UIKit

@MainActor
enum FloorPlan3DBuilder {
    /// 도면 전체(바닥·벽·문창문·콘센트·표시)를 담은 엔티티 하나
    static func makeScene(for plan: PlanData) -> Entity {
        let space = PlanSpace(plan: plan)
        let root = Entity()
        root.addChild(makeFloor(space: space))
        for wall in plan.walls where !wall.isVirtual {
            guard let line = plan.line(of: wall) else { continue }
            let openings = plan.doorWindows.filter { $0.wallId == wall.id }
            root.addChild(makeWall(wall, line: line, openings: openings, space: space))
        }
        for fixture in plan.wallFixtures {
            guard let wall = plan.wall(id: fixture.wallId), let line = plan.line(of: wall) else { continue }
            root.addChild(makeOutlet(fixture, wall: wall, line: line, space: space))
        }
        for marker in plan.markers {
            root.addChild(makeMarker(marker, space: space))
        }
        return root
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

    /// 엔티티의 +x 축이 도면 방향 direction을 향하게 하는 회전 (위아래 축 기준)
    static func orientation(along direction: SIMD2<Double>) -> simd_quatf {
        simd_quatf(angle: Float(atan2(-direction.y, direction.x)), axis: [0, 1, 0])
    }
}

// 바닥
extension FloorPlan3DBuilder {
    /// 도면보다 사방 1m 넓은 바닥
    private static func makeFloor(space: PlanSpace) -> ModelEntity {
        let margin = 1.0
        let mesh = MeshResource.generatePlane(
            width: Float(space.size.x + margin * 2),
            depth: Float(space.size.y + margin * 2)
        )
        return ModelEntity(mesh: mesh, materials: [Materials.floor])
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
    private static func makeWall(_ wall: Wall, line: WallLine, openings: [DoorWindow], space: PlanSpace) -> Entity {
        let entity = Entity()
        entity.position = space.world(line.start)
        entity.orientation = PlanSpace.orientation(along: line.direction)
        let pieces = wallPieces(length: line.length, thickness: wall.thickness, openings: openings)
        for piece in pieces {
            boxes(for: piece, wall: wall).forEach { entity.addChild($0) }
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
    private static func boxes(for piece: WallPiece, wall: Wall) -> [ModelEntity] {
        guard let opening = piece.opening else {
            return [box(piece, bottom: 0, top: wall.height, depth: wall.thickness, material: Materials.wall)].compactMap { $0 }
        }
        let top = min(opening.sillHeight + opening.height, wall.height)
        var result = [box(piece, bottom: top, top: wall.height, depth: wall.thickness, material: Materials.wall)]
        if opening.kind == .window {
            result.append(box(piece, bottom: 0, top: opening.sillHeight, depth: wall.thickness, material: Materials.wall))
            result.append(box(piece, bottom: opening.sillHeight, top: top, depth: 0.03, material: Materials.glass))
        }
        return result.compactMap { $0 }
    }

    /// 토막 구간에 bottom~top 높이의 상자. 너무 얇으면 만들지 않는다
    private static func box(_ piece: WallPiece, bottom: Double, top: Double, depth: Double, material: any Material) -> ModelEntity? {
        let width = piece.to - piece.from
        let height = top - bottom
        guard width > 0.001, height > 0.001 else { return nil }
        let mesh = MeshResource.generateBox(width: Float(width), height: Float(height), depth: Float(depth))
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.position = [Float((piece.from + piece.to) / 2), Float((bottom + top) / 2), 0]
        return entity
    }
}

// 콘센트와 표시
// TEMP: 콘센트·사람·발화지점은 RealityKit 기본 도형으로 만든 임시 모양 — Figma(43:21764)의 주황 3D 아이콘 에셋이 생기면 바꿈
extension FloorPlan3DBuilder {
    /// 벽 면에 붙은 콘센트
    private static func makeOutlet(_ fixture: WallFixture, wall: Wall, line: WallLine, space: PlanSpace) -> ModelEntity {
        let size = SIMD3<Float>(0.2, 0.2, 0.04)
        let normal = fixture.face == .left ? line.leftNormal : -line.leftNormal
        let offset = wall.thickness / 2 + Double(size.z) / 2
        let point = line.point(along: fixture.positionAlongWall) + normal * offset
        let entity = ModelEntity(mesh: .generateBox(size: size, cornerRadius: 0.02), materials: [Materials.stamp])
        entity.position = space.world(point, height: fixture.heightFromFloor)
        entity.orientation = PlanSpace.orientation(along: line.direction)
        return entity
    }

    /// 사람·발화지점. yaw는 도면 위쪽 0°에서 시계 방향이라, 위에서 볼 때 시계 방향 = 위아래 축 기준 음의 회전
    private static func makeMarker(_ marker: PlanMarker, space: PlanSpace) -> Entity {
        let entity = marker.kind == .person ? personModel(lying: marker.lying ?? false) : flameModel()
        entity.position = space.world(marker.position, height: marker.height)
        entity.orientation = simd_quatf(angle: Float(-marker.yaw * .pi / 180), axis: [0, 1, 0])
        return entity
    }

    /// 몸통과 머리. 누우면 머리가 바라보는 방향(-z)으로 눕는다
    private static func personModel(lying: Bool) -> Entity {
        let body = Entity()
        let torso = ModelEntity(mesh: .generateBox(width: 0.4, height: 1.2, depth: 0.25, cornerRadius: 0.1), materials: [Materials.stamp])
        torso.position = [0, 0.6, 0]
        let head = ModelEntity(mesh: .generateSphere(radius: 0.13), materials: [Materials.stamp])
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
    private static func flameModel() -> Entity {
        let cone = ModelEntity(mesh: .generateCone(height: 0.5, radius: 0.18), materials: [Materials.stamp])
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
    static let glass: PhysicallyBasedMaterial = {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: UIColor(resource: .gray200))
        material.blending = .transparent(opacity: 0.35)
        return material
    }()
}

// 3D 발화지점 불꽃. 끝이 뾰족한 물방울 모양 혀(舌) 세 개(바깥 불꽃 · 속불꽃 · 심지)를 안쪽으로 겹쳐 반투명한 불꽃 하나로 만들고,
// 바닥에는 스탬프가 차지하는 원 모양 범위와 불꽃 아이콘을 옅게 깔아 둔다.
// 혀는 뒷면만 그려서(앞면을 가리는 면이 없게) 안쪽 혀가 바깥 혀에 가리지 않고 또렷이 보인다.
// 흔드는 것은 혀 묶음(flameName)뿐이라 눌러 고르는 판정과 바닥 표시는 가만히 있는다

import RealityKit
import UIKit

extension FloorPlan3DBuilder {
    /// 불꽃 몸통 엔티티 이름. 화면은 이 이름으로 불꽃을 찾아 매 프레임 흔든다
    static let flameName = "flame"

    /// 불꽃: 흔들리는 혀 묶음. 바닥 표시(flameFloorMark)는 고른 표시 상자와 눌러 고르는 판정에 끼지 않게, 이 엔티티를 다 만든 뒤 따로 붙인다
    static func flameModel() -> Entity {
        let flame = Entity()
        flame.name = flameName
        // 겹친 반투명 면은 그리는 순서가 카메라 높이에 따라 뒤바뀌면 안쪽 색이 가려져서, 한 묶음으로 두고 tongues 순서대로 그리게 한다
        let sortGroup = ModelSortGroup()
        for (order, tongue) in FlameShape.tongues.enumerated() {
            guard let entity = flameTongue(tongue) else { continue }
            entity.components.set(ModelSortGroupComponent(group: sortGroup, order: Int32(order)))
            flame.addChild(entity)
        }
        let wrapper = Entity()
        wrapper.addChild(flame)
        return wrapper
    }

    /// 불꽃 모양 값 (m). 크기는 PoC 발화지점(높이 0.38)보다 키워 멀리서도 불꽃으로 보이게 했다
    // TEMP: 모양·색은 디자인에 3D 불꽃이 없어 임의로 정함. 색은 빨강·노랑이 없어 Orange 계열 안에서 바깥은 진하게, 안쪽일수록 연하게 했다
    private enum FlameShape {
        struct Tongue {
            let color: UIColor
            let opacity: Float
            let radius: Float
            let height: Float
            /// 끝이 옆(+x)으로 휘는 정도
            let bend: Float
        }

        /// 뒤에서 앞으로 그린다. 바깥 불꽃 → 속불꽃 → 심지 순서
        static let tongues: [Tongue] = [
            Tongue(color: UIColor(resource: .brand500), opacity: 0.85, radius: 0.16, height: 0.5, bend: 0.07),
            Tongue(color: UIColor(resource: .orange300), opacity: 0.9, radius: 0.105, height: 0.36, bend: 0.05),
            Tongue(color: UIColor(resource: .orange100), opacity: 0.95, radius: 0.055, height: 0.2, bend: 0.025)
        ]
        /// 한 혀의 둘레 조각 수와 높이 조각 수
        static let segments = 18
        static let rings = 14

        /// 바닥 표시: 스탬프가 차지하는 원의 반지름(PlanMarker.footprint, 크기 배율 1일 때)과 바닥에서 띄우는 높이.
        /// 겹쳐 놓은 발화지점끼리 같은 높이에서 깜빡이지 않게, 스탬프마다 조금씩 다르게 띄운다
        static let floorRadius: Float = 0.2
        static let floorLift: Float = 0.012
        static let floorLiftStep: Float = 0.001
        static let floorLiftSteps = 32
        /// 바닥 표시의 그림 크기(pt)와 칠·테두리·아이콘의 투명도 (높을수록 비침)
        // TEMP: 투명도는 Figma에 없어 임의로 정함
        static let floorTextureSize: CGFloat = 512
        static let floorFillAlpha: CGFloat = 0.18
        static let floorIconAlpha: CGFloat = 0.4
    }

    /// 끝이 뾰족한 물방울 모양 혀 하나. 높이 t(0~1)마다 반지름이 sin(π·t^0.75)^0.85로 변해 아래는 둥글고 끝은 뾰족하다
    private static func flameTongue(_ tongue: FlameShape.Tongue) -> ModelEntity? {
        let segments = FlameShape.segments
        let rings = FlameShape.rings
        var positions: [SIMD3<Float>] = []
        for ring in 0...rings {
            let t = Float(ring) / Float(rings)
            let radius = tongue.radius * pow(sin(.pi * pow(t, 0.75)), 0.85)
            let centerX = tongue.bend * t * t
            for segment in 0...segments {
                let angle = 2 * Float.pi * Float(segment) / Float(segments)
                positions.append([centerX + radius * cos(angle), tongue.height * t, radius * sin(angle)])
            }
        }
        var indices: [UInt32] = []
        let stride = UInt32(segments + 1)
        for ring in 0..<rings {
            for segment in 0..<segments {
                let a = UInt32(ring) * stride + UInt32(segment)
                let b = a + 1
                let c = a + stride
                let d = c + 1
                indices += [a, b, c, b, d, c]
            }
        }
        // 빛을 받지 않는 재질이라 법선은 쓰이지 않는다. 위쪽을 보게만 채워 둔다
        var descriptor = MeshDescriptor(name: "flameTongue")
        descriptor.positions = MeshBuffer(positions)
        descriptor.normals = MeshBuffer(positions.map { _ in SIMD3<Float>(0, 1, 0) })
        descriptor.primitives = .triangles(indices)
        guard let mesh = try? MeshResource.generate(from: [descriptor]) else { return nil }
        var material = UnlitMaterial(color: tongue.color)
        material.blending = .transparent(opacity: .init(scale: tongue.opacity))
        return ModelEntity(mesh: mesh, materials: [material])
    }
}

// 바닥 표시
extension FloorPlan3DBuilder {
    /// 바닥에 눕힌 원: 스탬프가 차지하는 정확한 범위(반지름 0.2m × 크기 배율)를 테두리로 보이고, 안은 옅게 칠한 뒤 불꽃 아이콘을 더 옅게 넣는다.
    /// 불꽃 엔티티의 자식으로 붙이므로 크기 배율은 엔티티 배율이 곱해 준다. markerID로 높이를 조금 달리해 겹친 스탬프끼리 깜빡이지 않게 한다
    static func flameFloorMark(markerID: String) -> ModelEntity? {
        guard let texture = flameFloorTexture else { return nil }
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: UIColor(resource: .brand500), texture: .init(texture))
        material.roughness = .init(floatLiteral: 1)
        material.metallic = .init(floatLiteral: 0)
        // 투명한 곳이 반짝여 사각형 판이 보이지 않게 반사를 끈다
        material.specular = .init(floatLiteral: 0)
        material.blending = .transparent(opacity: .init(floatLiteral: 1))
        let side = FlameShape.floorRadius * 2
        let entity = ModelEntity(mesh: .generatePlane(width: side, depth: side), materials: [material])
        let step = markerID.unicodeScalars.reduce(0) { $0 + Int($1.value) } % FlameShape.floorLiftSteps
        entity.position.y = FlameShape.floorLift + FlameShape.floorLiftStep * Float(step)
        // 겹친 반투명 판은 카메라가 움직일 때마다 앞뒤 순서가 뒤바뀌어 깜빡이므로, 높이 순서대로 그리게 못 박는다
        entity.components.set(ModelSortGroupComponent(group: floorSortGroup, order: Int32(step)))
        return entity
    }

    /// 모든 발화지점의 바닥 표시가 함께 쓰는 그리기 순서 묶음
    private static let floorSortGroup = ModelSortGroup()

    /// 흰색으로 그린 원 그림(테두리 · 옅은 칠 · 더 옅은 불꽃 아이콘). 색은 재질의 tint가 입힌다. 한 번만 만든다
    private static let flameFloorTexture: TextureResource? = {
        let size = FlameShape.floorTextureSize
        let lineWidth = size * 0.03
        let image = UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { _ in
            let circle = CGRect(x: 0, y: 0, width: size, height: size).insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
            UIColor.white.withAlphaComponent(FlameShape.floorFillAlpha).setFill()
            UIBezierPath(ovalIn: circle).fill()
            UIColor.white.setStroke()
            let ring = UIBezierPath(ovalIn: circle)
            ring.lineWidth = lineWidth
            ring.stroke()
            let configuration = UIImage.SymbolConfiguration(pointSize: size * 0.62, weight: .regular)
            guard let symbol = UIImage(systemName: EditTool.ignitionPoint.iconName, withConfiguration: configuration)?
                .withTintColor(.white.withAlphaComponent(FlameShape.floorIconAlpha), renderingMode: .alwaysOriginal) else { return }
            symbol.draw(at: CGPoint(x: (size - symbol.size.width) / 2, y: (size - symbol.size.height) / 2))
        }
        guard let cgImage = image.cgImage else { return nil }
        return try? TextureResource(image: cgImage, options: .init(semantic: .color))
    }()
}

// 불꽃 흔들기
extension FloorPlan3DBuilder {
    /// root 아래의 모든 불꽃 몸통. 장면을 만들 때마다 한 번 모아 두고 매 프레임 흔든다
    static func flames(in root: Entity) -> [Entity] {
        var found: [Entity] = []
        func collect(_ entity: Entity) {
            if entity.name == flameName {
                found.append(entity)
                return
            }
            entity.children.forEach(collect)
        }
        collect(root)
        return found
    }

    /// 불꽃을 시간 t(초)에 맞게 일렁이게 한다. 세 방향 배율을 서로 다른 빠르기로 흔들고, 불꽃마다 시작을 달리해 한꺼번에 움직이지 않게 한다.
    /// 빠르기가 모두 정수(9·13·8)라 t가 2π마다 되돌아와도 끊김이 없다
    static func animateFlames(_ flames: [Entity], time t: Float) {
        for (index, flame) in flames.enumerated() {
            let time = t + Float(index) * FlameWave.phaseStep
            flame.scale = SIMD3(
                1 + FlameWave.sideAmount * sin(time * 9),
                1 + FlameWave.heightAmount * sin(time * 13 + 1),
                1 + FlameWave.sideAmount * cos(time * 8)
            )
        }
    }

    /// 불꽃 흔들림 값 (PoC와 같음)
    private enum FlameWave {
        /// 가로·세로 폭이 흔들리는 정도 (5%)
        static let sideAmount: Float = 0.05
        /// 높이가 흔들리는 정도 (10%)
        static let heightAmount: Float = 0.1
        /// 불꽃마다 시작을 어긋나게 하는 시간 (초)
        static let phaseStep: Float = 0.7
    }
}

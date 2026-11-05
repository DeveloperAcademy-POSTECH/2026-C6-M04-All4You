//
//  RoomPlanScanThumbnailView.swift
//  All4You
//
//  Created by 채유성 on 11/3/26.
//

// 저장된 스캔 결과 또는 병합 결과물을 3차원 그래픽 축소 모형으로 화면에 표시하기 위한 View
import RoomPlan
import SceneKit
import SwiftUI
import simd

struct RoomPlanScanThumbnailView: UIViewRepresentable {
    let rooms: [CapturedRoom]
    let structure: CapturedStructure?
    let liveRoom: CapturedRoom?
    let revision: Int
    
    // View를 그릴 때 필요한 오브젝트, 재사용 노드, 조명 및 직교 카메라 상태 관리자
    final class Coordinator {
        var lastRevision: Int?
        var lastSize: CGSize = .zero
        let scene = SCNScene()
        var nodes: [SCNNode] = []
        let cameraNode = SCNNode()
        let wallMaterial = RoomPlanScanThumbnailView.material(color: .systemGray3)
        let floorMaterial = RoomPlanScanThumbnailView.material(color: .white)
        let objectMaterial = RoomPlanScanThumbnailView.material(color: .systemGray4)
        
        init() {
            scene.background.contents = UIColor.clear
            let camera = SCNCamera()
            camera.usesOrthographicProjection = true
            cameraNode.camera = camera
            scene.rootNode.addChildNode(cameraNode)
            let ambient = SCNNode()
            ambient.light = SCNLight()
            ambient.light?.type = .ambient
            ambient.light?.intensity = 800
            scene.rootNode.addChildNode(ambient)
            let keyLight = SCNNode()
            keyLight.light = SCNLight()
            keyLight.light?.type = .directional
            keyLight.light?.intensity = 1_000
            keyLight.light?.castsShadow = true
            keyLight.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 4, 0)
            scene.rootNode.addChildNode(keyLight)
        }
    }
    
    func makeCoordinator() -> Coordinator { Coordinator() }
    
    // 배경 투명도와 고정 화면 렌더링 속성이 설정된 scenekit view 생성
    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.isOpaque = false
        view.allowsCameraControl = false
        view.isUserInteractionEnabled = false
        view.antialiasingMode = .multisampling4X
        view.rendersContinuously = false
        view.preferredFramesPerSecond = 30
        view.scene = context.coordinator.scene
        view.pointOfView = context.coordinator.cameraNode
        return view
    }
    
    // 병합된 전체 구조 또는 개별 방들의 벽, 바닥, 물체 정보를 실시간으로 갱신
    func updateUIView(_ view: SCNView, context: Context) {
        // 데이터 버전이나 화면 크기가 변경된 경우에만 scene 구성 요소 재설정
        guard context.coordinator.lastRevision != revision
                || context.coordinator.lastSize != view.bounds.size else { return }
        let isFirstUpdate = context.coordinator.lastRevision == nil
        context.coordinator.lastRevision = revision
        context.coordinator.lastSize = view.bounds.size
        let scene = context.coordinator.scene
        let wallMaterial = context.coordinator.wallMaterial
        let floorMaterial = context.coordinator.floorMaterial
        let objectMaterial = context.coordinator.objectMaterial
        var nodes: [SCNNode] = []
        var nodeIndex = 0
        
        // 스캔 결과가 3차원 모형으로 부드럽게 나타나도록 애니메이션 설정 적용
        SCNTransaction.begin()
        SCNTransaction.animationDuration = isFirstUpdate ? 0 : 0.18
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        func updateNode(width: CGFloat, height: CGFloat, length: CGFloat,
                        transform: simd_float4x4, material: SCNMaterial) {
            let node: SCNNode
            if nodeIndex < context.coordinator.nodes.count {
                node = context.coordinator.nodes[nodeIndex]
                if let box = node.geometry as? SCNBox {
                    // 크기 변화가 있는 상자 모형만 효율적으로 재사용하여 갱신
                    if abs(box.width - width) > 0.005 { box.width = width }
                    if abs(box.height - height) > 0.005 { box.height = height }
                    if abs(box.length - length) > 0.005 { box.length = length }
                    if box.firstMaterial !== material { box.materials = [material] }
                }
            } else {
                node = SCNNode(geometry: SCNBox(width: width, height: height,
                                                length: length, chamferRadius: 0))
                node.geometry?.materials = [material]
                node.opacity = 0
                scene.rootNode.addChildNode(node)
                context.coordinator.nodes.append(node)
            }
            node.simdTransform = transform
            node.opacity = 1
            nodes.append(node)
            nodeIndex += 1
        }
        
        // 병합된 구조 데이터 존재 여부에 따른 표시 대상 분기 처리
        var focusNodes: [SCNNode] = []
        let displayedRooms = structure == nil ? rooms : (liveRoom.map { [$0] } ?? [])
        if let structure {
            for wall in structure.walls {
                updateNode(width: CGFloat(max(wall.dimensions.x, 0.02)),
                           height: CGFloat(max(wall.dimensions.y, 0.02)),
                           length: 0.05, transform: wall.transform, material: wallMaterial)
            }
            for floor in structure.floors {
                updateNode(width: CGFloat(max(floor.dimensions.x, 0.02)),
                           height: CGFloat(max(floor.dimensions.y, 0.02)),
                           length: 0.03, transform: floor.transform, material: floorMaterial)
            }
            for object in structure.objects {
                updateNode(width: CGFloat(max(object.dimensions.x, 0.02)),
                           height: CGFloat(max(object.dimensions.y, 0.02)),
                           length: CGFloat(max(object.dimensions.z, 0.02)),
                           transform: object.transform, material: objectMaterial)
            }
        }
        for (roomIndex, room) in displayedRooms.enumerated() {
            let roomStartIndex = nodes.count
            for wall in room.walls {
                updateNode(width: CGFloat(max(wall.dimensions.x, 0.02)),
                           height: CGFloat(max(wall.dimensions.y, 0.02)),
                           length: 0.05, transform: wall.transform, material: wallMaterial)
            }
            for floor in room.floors {
                updateNode(width: CGFloat(max(floor.dimensions.x, 0.02)),
                           height: CGFloat(max(floor.dimensions.y, 0.02)),
                           length: 0.03, transform: floor.transform, material: floorMaterial)
            }
            for object in room.objects {
                updateNode(width: CGFloat(max(object.dimensions.x, 0.02)),
                           height: CGFloat(max(object.dimensions.y, 0.02)),
                           length: CGFloat(max(object.dimensions.z, 0.02)),
                           transform: object.transform, material: objectMaterial)
            }
            if roomIndex == displayedRooms.count - 1 {
                focusNodes = Array(nodes.dropFirst(roomStartIndex))
            }
        }
        
        for node in context.coordinator.nodes.dropFirst(nodeIndex) { node.removeFromParentNode() }
        context.coordinator.nodes.removeSubrange(nodeIndex...)
        guard !nodes.isEmpty else {
            SCNTransaction.commit()
            return
        }
        
        // 구간 병합 전의 마지막 방 또는 병합 완료 후의 전체 구조를 기준 삼아 카메라 프레이밍
        let fittedNodes = structure == nil && !focusNodes.isEmpty ? focusNodes : nodes
        let positions = fittedNodes.map(\.simdPosition)
        let minX = positions.map(\.x).min() ?? 0
        let maxX = positions.map(\.x).max() ?? 0
        let minZ = positions.map(\.z).min() ?? 0
        let maxZ = positions.map(\.z).max() ?? 0
        let centerX = (minX + maxX) / 2
        let centerZ = (minZ + maxZ) / 2
        let span = max(maxX - minX, maxZ - minZ, 2)
        
        guard let camera = context.coordinator.cameraNode.camera else {
            SCNTransaction.commit()
            return
        }
        let cameraNode = context.coordinator.cameraNode
        cameraNode.position = SCNVector3(centerX + span, span * 1.5, centerZ + span)
        cameraNode.look(at: SCNVector3(centerX, 0, centerZ))
        
        // 방 모형이 화면 안에서 차지하는 범위를 계산해 크기 조절
        let projected = fittedNodes.flatMap { node -> [SCNVector3] in
            let (minimum, maximum) = node.boundingBox
            return [minimum.x, maximum.x].flatMap { x in
                [minimum.y, maximum.y].flatMap { y in
                    [minimum.z, maximum.z].map { z in
                        let world = node.convertPosition(SCNVector3(x, y, z), to: nil)
                        return cameraNode.convertPosition(world, from: nil)
                    }
                }
            }
        }
        let projectedX = projected.map(\.x)
        let projectedY = projected.map(\.y)
        let minProjectedX = projectedX.min() ?? 0
        let maxProjectedX = projectedX.max() ?? 1
        let minProjectedY = projectedY.min() ?? 0
        let maxProjectedY = projectedY.max() ?? 1
        let modelWidth = maxProjectedX - minProjectedX
        let modelHeight = maxProjectedY - minProjectedY
        let aspect = view.bounds.height > 0 ? view.bounds.width / view.bounds.height : 4.0 / 3.0
        camera.orthographicScale = Double(max(modelHeight, modelWidth / Float(max(aspect, 0.1)), 0.5) * 1.16)
        let offset = cameraNode.convertVector(
            SCNVector3((minProjectedX + maxProjectedX) / 2, (minProjectedY + maxProjectedY) / 2, 0),
            to: nil
        )
        cameraNode.position = SCNVector3(
            cameraNode.position.x + offset.x,
            cameraNode.position.y + offset.y,
            cameraNode.position.z + offset.z
        )
        
        SCNTransaction.commit()
    }
    
    // 벽, 바닥, 물체 요소가 자연스럽게 보이도록 재지 추가
    private static func material(color: UIColor) -> SCNMaterial {
        let value = SCNMaterial()
        value.diffuse.contents = color
        value.lightingModel = .physicallyBased
        value.roughness.contents = 0.85
        value.isDoubleSided = true
        return value
    }
}

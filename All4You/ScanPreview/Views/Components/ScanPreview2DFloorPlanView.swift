//
//  ScanPreviewFloorPlanView.swift
//  All4You
//
//  Created by 채유성 on 11/6/26.
//

// RoomPlan 스캔 결과를 2D 도면으로 표시하는 뷰
// MARK: 다른 부분에서 3D 도면을 2D 도면으로 변환하는 코드 있다면 삭제
import RoomPlan
import SwiftUI
import simd

struct ScanPreview2DFloorPlanView: View {
    let rooms: [CapturedRoom]
    let structure: CapturedStructure?
    
    private struct Segment {
        let start: CGPoint
        let end: CGPoint
    }
    
    var body: some View {
        Canvas { context, size in
            let floors = floorSurfaces.map(floorFootprint)
            let objects = scannedObjects.map(objectFootprint)
            let walls = wallSurfaces.map(surfaceSegment)
            let doors = doorSurfaces.map(surfaceSegment)
            let windows = windowSurfaces.map(surfaceSegment)
            let openings = openingSurfaces.map(surfaceSegment)
            let points = floors.flatMap { $0 } + objects.flatMap { $0 }
            + walls.flatMap { [$0.start, $0.end] }
            guard !points.isEmpty else { return }
            
            let minX = points.map(\.x).min() ?? 0
            let maxX = points.map(\.x).max() ?? 1
            let minY = points.map(\.y).min() ?? 0
            let maxY = points.map(\.y).max() ?? 1
            let scale = min(
                (size.width - 32) / max(maxX - minX, 0.1),
                (size.height - 32) / max(maxY - minY, 0.1)
            )
            let center = CGPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2)
            func mapped(_ point: CGPoint) -> CGPoint {
                CGPoint(x: size.width / 2 + (point.x - center.x) * scale,
                        y: size.height / 2 + (point.y - center.y) * scale)
            }
            func line(_ segment: Segment, color: Color, width: CGFloat) {
                var path = Path()
                path.move(to: mapped(segment.start))
                path.addLine(to: mapped(segment.end))
                context.stroke(path, with: .color(color),
                               style: StrokeStyle(lineWidth: width, lineCap: .square))
            }
            
            // 바닥, 가구, 벽 순서로 그려서 내부 요소가 벽 선 위에 덮이지 않도록 함
            for footprint in floors {
                let path = polygonPath(footprint.map(mapped))
                context.fill(path, with: .color(Color(uiColor: .systemGray5)))
                context.stroke(path, with: .color(.gray.opacity(0.2)), lineWidth: 1)
            }
            for footprint in objects {
                let path = polygonPath(footprint.map(mapped))
                context.fill(path, with: .color(Color(uiColor: .systemGray4).opacity(0.65)))
                context.stroke(path, with: .color(.gray), lineWidth: 1)
            }
            for wall in walls { line(wall, color: .black, width: 3) }
            
            // 벽 위의 문·창문·개구부를 빈 공간으로 지운 뒤 종류별 선 표시
            for gap in openings + doors + windows { line(gap, color: .white, width: 7) }
            for door in doors { line(door, color: .gray, width: 1.5) }
            for window in windows { line(window, color: .blue, width: 2) }
        }
        .accessibilityLabel("벽, 문, 창문, 물체가 표시된 스캔 공간의 2D 평면도")
    }
    
    private var wallSurfaces: [CapturedRoom.Surface] {
        structure?.walls ?? rooms.flatMap(\.walls)
    }
    private var floorSurfaces: [CapturedRoom.Surface] {
        structure?.floors ?? rooms.flatMap(\.floors)
    }
    private var doorSurfaces: [CapturedRoom.Surface] {
        structure?.doors ?? rooms.flatMap(\.doors)
    }
    private var windowSurfaces: [CapturedRoom.Surface] {
        structure?.windows ?? rooms.flatMap(\.windows)
    }
    private var openingSurfaces: [CapturedRoom.Surface] {
        structure?.openings ?? rooms.flatMap(\.openings)
    }
    private var scannedObjects: [CapturedRoom.Object] {
        structure?.objects ?? rooms.flatMap(\.objects)
    }
    
    private func surfaceSegment(_ surface: CapturedRoom.Surface) -> Segment {
        let center = surface.transform.columns.3
        let axis = surface.transform.columns.0
        let halfWidth = CGFloat(surface.dimensions.x) / 2
        return Segment(
            start: CGPoint(x: CGFloat(center.x) - CGFloat(axis.x) * halfWidth,
                           y: CGFloat(center.z) - CGFloat(axis.z) * halfWidth),
            end: CGPoint(x: CGFloat(center.x) + CGFloat(axis.x) * halfWidth,
                         y: CGFloat(center.z) + CGFloat(axis.z) * halfWidth)
        )
    }
    
    private func floorFootprint(_ floor: CapturedRoom.Surface) -> [CGPoint] {
        footprint(transform: floor.transform, halfWidth: floor.dimensions.x / 2,
                  halfDepth: floor.dimensions.y / 2, depthOnLocalY: true)
    }
    
    private func objectFootprint(_ object: CapturedRoom.Object) -> [CGPoint] {
        footprint(transform: object.transform, halfWidth: object.dimensions.x / 2,
                  halfDepth: object.dimensions.z / 2, depthOnLocalY: false)
    }
    
    private func footprint(
        transform: simd_float4x4,
        halfWidth: Float,
        halfDepth: Float,
        depthOnLocalY: Bool
    ) -> [CGPoint] {
        [(-halfWidth, -halfDepth), (halfWidth, -halfDepth),
         (halfWidth, halfDepth), (-halfWidth, halfDepth)].map { x, depth in
            let local = depthOnLocalY
            ? SIMD4<Float>(x, depth, 0, 1)
            : SIMD4<Float>(x, 0, depth, 1)
            let world = transform * local
            return CGPoint(x: CGFloat(world.x), y: CGFloat(world.z))
        }
    }
    
    private func polygonPath(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        path.closeSubpath()
        return path
    }
}

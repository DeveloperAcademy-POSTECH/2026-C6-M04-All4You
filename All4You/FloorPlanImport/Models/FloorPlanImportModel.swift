import UIKit
import CoreImage
import Vision

/// 종이의 네 모서리. 왼쪽 위부터 시계 방향이며 좌표 범위는 0...1이다.
struct FloorPlanImportRegion {
    private(set) var corners = [
        CGPoint(x: 0.08, y: 0.08), CGPoint(x: 0.92, y: 0.08),
        CGPoint(x: 0.92, y: 0.92), CGPoint(x: 0.08, y: 0.92)
    ]

    mutating func update(_ points: [CGPoint]) {
        if points.count != 4 {
            return
        }
        // 좌표 범위는 드래그 화면과 Vision에서 이미 0...1로 맞춘다.
        // 끝에서도 다음 모서리를 읽을 수 있도록 처음 두 점을 뒤에 붙인다.
        let outline = points + [points[0], points[1]]
        for index in 0..<4 {
            let first = outline[index]
            let second = outline[index + 1]
            let third = outline[index + 2]

            // 세 점이 시계 방향으로 꺾여야 모서리가 교차하지 않는다.
            let turn = (second.x - first.x) * (third.y - second.y)
                - (second.y - first.y) * (third.x - second.x)
            if turn <= 0.003 { return }
            if turn.isFinite == false { return }
        }
        corners = points
    }
}

/// 사진 방향 정리, 종이 인식, 원근 보정을 담당한다.
enum FloorPlanImportImageProcessor {
    // 보정할 때마다 새로 만들지 않고 재사용한다.
    nonisolated private static let context = CIContext()

    /// 자동 촬영은 문서 전체가 인식될 때만 허용한다.
    /// 수동 촬영 후에는 일반 사각형 인식도 영역 조정의 시작점으로 사용한다.
    nonisolated static func detectPaper(
        in image: VNImageRequestHandler,
        allowRectangleFallback: Bool = true
    ) -> [CGPoint]? {
        let documentRequest = VNDetectDocumentSegmentationRequest()
        do {
            try image.perform([documentRequest])
            if let document = documentRequest.results?.first {
                if document.confidence >= 0.6 {
                    return screenCorners(of: document)
                }
            }
        } catch {
            // 문서 인식에 실패해도 직접 촬영과 모서리 조정은 사용할 수 있다.
        }
        if allowRectangleFallback == false {
            return nil
        }

        let rectangleRequest = VNDetectRectanglesRequest()
        rectangleRequest.maximumObservations = 3
        rectangleRequest.minimumConfidence = 0.65
        rectangleRequest.minimumSize = 0.2
        rectangleRequest.minimumAspectRatio = 0.3
        do {
            try image.perform([rectangleRequest])
        } catch {
            return nil
        }
        let paper = rectangleRequest.results?.max { first, second in
            first.boundingBox.width * first.boundingBox.height
                < second.boundingBox.width * second.boundingBox.height
        }
        guard let paper = paper else { return nil }
        return screenCorners(of: paper)
    }

    nonisolated private static func screenCorners(of paper: VNRectangleObservation) -> [CGPoint] {
        let points = [paper.topLeft, paper.topRight, paper.bottomRight, paper.bottomLeft]
        // Vision과 화면의 Y좌표 방향을 맞춘다.
        return points.map { point in
            CGPoint(x: point.x, y: 1 - point.y)
        }
    }

    nonisolated static func prepare(_ image: UIImage) -> (image: UIImage, corners: [CGPoint]?) {
        // 큰 사진은 긴 변을 2400까지 줄이고, 작은 사진은 확대하지 않는다.
        let longestSide = max(image.size.width, image.size.height)
        let scale = min(1, 2400 / longestSide)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        // 화면 회전 정보를 픽셀에 반영해 모서리 위치와 사진 방향을 맞춘다.
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let upright = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let cgImage = upright.cgImage else { return (upright, nil) }

        let imageRequest = VNImageRequestHandler(cgImage: cgImage)
        return (upright, detectPaper(in: imageRequest))
    }

    nonisolated static func correct(_ image: UIImage, corners: [CGPoint]) -> UIImage? {
        if corners.count != 4 { return nil }
        guard let input = CIImage(image: image) else { return nil }
        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else { return nil }

        filter.setValue(input, forKey: kCIInputImageKey)
        let keys = ["inputTopLeft", "inputTopRight", "inputBottomRight", "inputBottomLeft"]
        for index in 0..<4 {
            let corner = corners[index]
            let position = CIVector(
                x: corner.x * input.extent.width,
                y: (1 - corner.y) * input.extent.height
            )
            filter.setValue(position, forKey: keys[index])
        }
        guard let output = filter.outputImage else { return nil }
        if output.extent.isEmpty { return nil }
        guard let cgImage = context.createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

/// 촬영 화면과 카메라에서 함께 쓰는 안내 문구.
enum FloorPlanImportText {
    static let adjustPaper = "종이 전체가 보이도록 위치를 조정해 주세요"
    static let fitPaper = "종이를 네모난 영역 안에 맞춰주세요"
    static let manualCapture = "촬영 버튼을 눌러 직접 촬영해 주세요"
}

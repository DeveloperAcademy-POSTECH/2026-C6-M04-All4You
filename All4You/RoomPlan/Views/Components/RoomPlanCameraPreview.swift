//
//  RoomPlanCameraPreview.swift
//  All4You
//
//  Created by 채유성 on 11/3/26.
//

// 스캔 일시정지시 화면에 보여줄 미리보기 뷰
import ARKit
import CoreImage
import MetalKit
import SwiftUI

// 스캔 전과 일시정지 중 공유 ARSession의 카메라 프레임을 Metal 화면에 출력하는 SwiftUI Wrapper
struct RoomPlanCameraPreview: UIViewRepresentable {
    let arSession: ARSession
    let isActive: Bool
    
    // ARSession을 참조하는 Metal 카메라 화면 생성
    func makeUIView(context: Context) -> ARCameraFrameView {
        let view = ARCameraFrameView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.arSession = arSession
        view.isPaused = !isActive
        return view
    }
    
    // 촬영 단계에 따른 프레임 렌더링의 활성 상태 동기화
    func updateUIView(_ view: ARCameraFrameView, context: Context) {
        view.arSession = arSession
        view.isPaused = !isActive
    }
}

// 스캔 종료 후 카메라 세션이 해제되어도 종료 버튼을 눌렀을 때 장면을 배경으로 유지하기 위한 단일 프레임 변환
enum RoomPlanCameraSnapshot {
    private static let imageContext = CIContext()
    
    static func capture(from arSession: ARSession, orientation: UIInterfaceOrientation) -> UIImage? {
        guard let frame = arSession.currentFrame else { return nil }
        let image = CIImage(cvPixelBuffer: frame.capturedImage)
            .oriented(orientation.imageOrientation)
        guard let cgImage = imageContext.createCGImage(image, from: image.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

// ARFrame의 카메라 픽셀 버퍼를 방향과 화면 비율에 맞춰 Metal 표면에 출력하는 뷰
final class ARCameraFrameView: MTKView, MTKViewDelegate {
    var arSession: ARSession?
    private let imageContext: CIContext
    private let commandQueue: MTLCommandQueue?
    
    override init(frame: CGRect, device: (any MTLDevice)?) {
        let metalDevice = device ?? MTLCreateSystemDefaultDevice()
        imageContext = metalDevice.map(CIContext.init(mtlDevice:)) ?? CIContext()
        commandQueue = metalDevice?.makeCommandQueue()
        super.init(frame: frame, device: metalDevice)
        framebufferOnly = false
        colorPixelFormat = .bgra8Unorm
        preferredFramesPerSecond = 30
        isPaused = false
        enableSetNeedsDisplay = false
        isUserInteractionEnabled = false
        delegate = self
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    // 현재 AR 프레임의 화면 방향 보정과 화면 비율에 맞춘 중앙 크롭
    func draw(in view: MTKView) {
        // 공유 ARSession의 최신 카메라 프레임을 drawable 크기에 맞춰 Metal로 출력
        guard let frame = arSession?.currentFrame,
              let drawable = currentDrawable,
              let commandBuffer = commandQueue?.makeCommandBuffer() else { return }
        
        let orientation = window?.windowScene?.effectiveGeometry.interfaceOrientation ?? .landscapeRight
        let image = CIImage(cvPixelBuffer: frame.capturedImage).oriented(orientation.imageOrientation)
        let width = CGFloat(drawable.texture.width)
        let height = CGFloat(drawable.texture.height)
        let scale = max(width / image.extent.width, height / image.extent.height)
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let centered = scaled.transformed(by: CGAffineTransform(
            translationX: (width - scaled.extent.width) / 2 - scaled.extent.minX,
            y: (height - scaled.extent.height) / 2 - scaled.extent.minY
        ))
        
        imageContext.render(
            centered,
            to: drawable.texture,
            commandBuffer: commandBuffer,
            bounds: CGRect(x: 0, y: 0, width: width, height: height),
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

// 화면 방향을 카메라 픽셀 버퍼의 회전 값으로 변환
private extension UIInterfaceOrientation {
    var imageOrientation: CGImagePropertyOrientation {
        switch self {
        case .portrait: .right
        case .portraitUpsideDown: .left
        case .landscapeLeft: .down
        case .landscapeRight: .up
        default: .up
        }
    }
}

//
//  CameraPreview.swift
//  All4You
//
//  Created by SIA on 11/9/26.
//

// 카메라가 보고 있는 화면을 그대로 보여 주는 뷰. SwiftUI에는 카메라 미리보기가 없어 UIKit 뷰를 감싼다

import AVFoundation
import SwiftUI

struct CameraPreview: UIViewRepresentable {
    let camera: PhotoCaptureCamera

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = camera.session
        // 화면을 빈틈없이 채우고 넘치는 부분은 잘라 낸다
        view.previewLayer.videoGravity = .resizeAspectFill
        camera.attachPreview(view.previewLayer)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    /// 바탕 레이어가 곧 미리보기 레이어인 뷰. 뷰 크기가 바뀌면 미리보기도 함께 바뀐다
    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        var previewLayer: AVCaptureVideoPreviewLayer {
            // layerClass를 위에서 정했으므로 항상 미리보기 레이어다
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}

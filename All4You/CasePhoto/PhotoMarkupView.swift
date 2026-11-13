// 사진 위에 손글씨·표시를 그리는 마크업 화면. 애플 기본 도구 막대(PencilKit)를 쓴다

import PencilKit
import SwiftUI

/// 사진 위에 그린 뒤 체크를 누르면 그림을 사진에 합쳐 돌려준다
struct PhotoMarkupView: View {
    let image: UIImage
    let initialDrawingData: Data?
    let onCancel: () -> Void
    /// 그림을 합친 사진과 목록용 작은 사진
    let onSave: (UIImage, UIImage, Data) -> Void

    @State private var canvasView = PKCanvasView()
    @State private var isSaving = false

    init(image: UIImage, initialDrawingData: Data? = nil, onCancel: @escaping () -> Void, onSave: @escaping (UIImage, UIImage, Data) -> Void) {
        self.image = image
        self.initialDrawingData = initialDrawingData
        self.onCancel = onCancel
        self.onSave = onSave
        let canvas = PKCanvasView()
        if let initialDrawingData, let drawing = try? PKDrawing(data: initialDrawingData) {
            canvas.drawing = drawing
        }
        _canvasView = State(initialValue: canvas)
    }

    var body: some View {
        GeometryReader { proxy in
            let rect = fittedRect(in: proxy.size)
            ZStack(alignment: .topLeading) {
                Color.black
                Image(uiImage: image)
                    .resizable()
                    .frame(width: rect.width, height: rect.height)
                    .offset(x: rect.minX, y: rect.minY)
                // 그림판을 사진과 같은 자리·크기로 덮어서, 그림 좌표가 사진 좌표와 같은 비율이 되게 한다
                MarkupCanvas(canvasView: canvasView)
                    .frame(width: rect.width, height: rect.height)
                    .offset(x: rect.minX, y: rect.minY)
            }
        }
        .ignoresSafeArea()
        .overlay(alignment: .top) {
            HStack {
                GlassCircleButton(title: Copy.cancel, systemImage: "chevron.left", action: onCancel)
                Spacer()
                GlassCircleButton(title: Copy.done, systemImage: "checkmark", isProminent: true, action: save)
                    .disabled(isSaving)
            }
            .padding(Layout.edgePadding)
        }
        .statusBarHidden()
    }
}

// 저장
extension PhotoMarkupView {
    /// 사진 원래 크기로 사진과 그림을 겹쳐 그린다. 그림판은 화면 크기라 사진 크기에 맞게 늘려 그린다
    private func save() {
        let canvasSize = canvasView.bounds.size
        guard canvasSize.width > 0 else { return }
        isSaving = true
        let image = image
        let scale = image.size.width / canvasSize.width * image.scale
        let drawing = canvasView.drawing
        let drawingData = drawing.dataRepresentation()
        let strokes = drawing.image(from: CGRect(origin: .zero, size: canvasSize), scale: scale)
        // 큰 사진을 다시 그리는 일은 시간이 걸려 메인 스레드 밖에서 한다
        Task.detached(priority: .userInitiated) {
            let format = UIGraphicsImageRendererFormat()
            format.scale = image.scale
            let merged = UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
                let bounds = CGRect(origin: .zero, size: image.size)
                image.draw(in: bounds)
                strokes.draw(in: bounds)
            }
            let thumbnail = LoadedPhoto.makeThumbnail(from: merged)
            await MainActor.run {
                onSave(merged, thumbnail, drawingData)
            }
        }
    }

    /// 사진을 비율 그대로 화면 가운데에 꽉 차게 놓은 자리
    private func fittedRect(in size: CGSize) -> CGRect {
        guard image.size.width > 0, image.size.height > 0 else { return .zero }
        let scale = min(size.width / image.size.width, size.height / image.size.height)
        let fitted = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        return CGRect(
            origin: CGPoint(x: (size.width - fitted.width) / 2, y: (size.height - fitted.height) / 2),
            size: fitted
        )
    }
}

/// 투명한 PencilKit 그림판. 화면에 붙으면 애플 기본 도구 막대를 띄운다
private struct MarkupCanvas: UIViewRepresentable {
    let canvasView: PKCanvasView

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        // 애플 펜슬이 없어도 손가락으로 그릴 수 있게 한다
        canvasView.drawingPolicy = .anyInput
        // Figma처럼 흰 펜으로 시작한다
        canvasView.tool = PKInkingTool(.pen, color: .white, width: PhotoMarkupView.Layout.penWidth)
        context.coordinator.toolPicker.addObserver(canvasView)
        context.coordinator.toolPicker.setVisible(true, forFirstResponder: canvasView)
        // 화면에 붙은 뒤에야 첫 응답자가 될 수 있어 다음 차례로 미룬다
        DispatchQueue.main.async {
            canvasView.becomeFirstResponder()
        }
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}

    static func dismantleUIView(_ uiView: PKCanvasView, coordinator: Coordinator) {
        coordinator.toolPicker.setVisible(false, forFirstResponder: uiView)
        coordinator.toolPicker.removeObserver(uiView)
    }

    final class Coordinator {
        let toolPicker: PKToolPicker = {
            // 첫 번째 펜
            let firstPen = PKToolPickerInkingItem(
                type: .pen,
                color: .red,
                width: 4
            )

            // 두 번째 펜
            let secondPen = PKToolPickerInkingItem(
                type: .monoline,
                color: .white,
                width: 1
            )
            
            // 하이라이트
            let highlighter = PKToolPickerInkingItem(
                type: .marker,
                color: nil,
                width: 8
            )

            // 지우개
            let eraser = PKToolPickerEraserItem(
                type: .vector
            )

            // 올가미
            let lasso = PKToolPickerLassoItem()

            // 눈금자 (블러 현상 확인을 위한 임시 도구)
            let ruler = PKToolPickerRulerItem()

            return PKToolPicker(toolItems: [
                firstPen,
                secondPen,
                highlighter,
                eraser,
                lasso,
                ruler
            ])
        }()
    }
}

// 크기
extension PhotoMarkupView {
    fileprivate enum Layout {
        static let edgePadding: CGFloat = 24
        static let penWidth: CGFloat = 4
    }
}

// 문구
extension PhotoMarkupView {
    private enum Copy {
        static let cancel = "마크업 취소"
        static let done = "마크업 완료"
    }
}

#Preview {
    PhotoMarkupView(image: UIImage(systemName: "flame")!, onCancel: {}, onSave: { _, _, _ in })
}

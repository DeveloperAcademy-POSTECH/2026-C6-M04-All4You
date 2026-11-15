// 사진 위에 손글씨·표시를 그리는 마크업 화면.
// 사진과 PencilKit 캔버스를 함께 확대해 그리기 좌표를 유지한다.

import PencilKit
import SwiftUI

struct PhotoMarkupView: View {
    let image: UIImage
    let initialDrawingData: Data?
    let onCancel: () -> Void
    let onSave: (UIImage, UIImage, Data) -> Void
    
    @State private var canvasView = PKCanvasView()
    @State private var isSaving = false
    
    init(
        image: UIImage,
        initialDrawingData: Data? = nil,
        onCancel: @escaping () -> Void,
        onSave: @escaping (UIImage, UIImage, Data) -> Void
    ) {
        self.image = image
        self.initialDrawingData = initialDrawingData
        self.onCancel = onCancel
        self.onSave = onSave
        
        let canvas = PKCanvasView()
        if let initialDrawingData,
           let drawing = try? PKDrawing(data: initialDrawingData) {
            canvas.drawing = drawing
        }
        _canvasView = State(initialValue: canvas)
    }
    
    var body: some View {
        GeometryReader { proxy in
            let rect = fittedRect(in: proxy.size)
            
            ZStack {
                Color.black
                
                ZoomableMarkupCanvas(image: image, canvasView: canvasView)
                    .frame(width: rect.width, height: rect.height)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .overlay(alignment: .top) {
            HStack {
                glassButton(
                    title: "마크업 취소",
                    systemImage: "chevron.left",
                    action: onCancel
                )
                
                Spacer()
                
                glassButton(
                    title: "마크업 완료",
                    systemImage: "checkmark",
                    isProminent: true,
                    action: save
                )
                .disabled(isSaving)
            }
            .padding(24)
        }
        .statusBarHidden()
    }
    
    private func glassButton(
        title: String,
        systemImage: String,
        isProminent: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(AppTypography.headlineEmphasized)
                .foregroundStyle(isProminent ? Color.white : Color.primary)
                .frame(width: 44, height: 44)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(
            isProminent
            ? .regular.tint(.brand500).interactive()
            : .regular.interactive(),
            in: .circle
        )
        .accessibilityLabel(title)
    }
    
    private func save() {
        // 외부 스크롤 뷰가 확대되더라도 캔버스 bounds는 원래 좌표 크기를 유지한다.
        let canvasSize = canvasView.bounds.size
        guard canvasSize.width > 0, canvasSize.height > 0 else { return }
        isSaving = true
        
        let image = image
        let scale = image.size.width / canvasSize.width * image.scale
        let drawing = canvasView.drawing
        let drawingData = drawing.dataRepresentation()
        let strokes = drawing.image(
            from: CGRect(origin: .zero, size: canvasSize),
            scale: scale
        )
        
        Task.detached(priority: .userInitiated) {
            let format = UIGraphicsImageRendererFormat()
            format.scale = image.scale
            
            let merged = UIGraphicsImageRenderer(
                size: image.size,
                format: format
            ).image { _ in
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
    
    private func fittedRect(in size: CGSize) -> CGRect {
        guard image.size.width > 0, image.size.height > 0 else { return .zero }
        let scale = min(
            size.width / image.size.width,
            size.height / image.size.height
        )
        let fitted = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )
        return CGRect(
            origin: CGPoint(
                x: (size.width - fitted.width) / 2,
                y: (size.height - fitted.height) / 2
            ),
            size: fitted
        )
    }
}

/// 바깥 UIScrollView가 사진과 캔버스를 하나의 뷰로 확대한다.
/// 캔버스 자체는 확대하지 않으므로 드로잉 저장 좌표가 변하지 않는다.
private struct ZoomableMarkupCanvas: UIViewRepresentable {
    let image: UIImage
    let canvasView: PKCanvasView
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 5
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.backgroundColor = .clear
        scrollView.clipsToBounds = true
        // 기본 배율에서는 한 손가락 드로잉을 가로채지 않는다.
        scrollView.panGestureRecognizer.minimumNumberOfTouches = 2
        
        let contentView = UIView()
        contentView.backgroundColor = .clear
        scrollView.addSubview(contentView)
        
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleToFill
        imageView.isUserInteractionEnabled = false
        contentView.addSubview(imageView)
        
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.isScrollEnabled = false
        canvasView.minimumZoomScale = 1
        canvasView.maximumZoomScale = 1
        canvasView.pinchGestureRecognizer?.isEnabled = false
        // 기존처럼 손가락으로도 그릴 수 있도록 유지한다.
        canvasView.drawingPolicy = .anyInput
        canvasView.tool = PKInkingTool(.pen, color: .red, width: 4)
        contentView.addSubview(canvasView)
        
        context.coordinator.contentView = contentView
        context.coordinator.imageView = imageView
        context.coordinator.canvasView = canvasView
        context.coordinator.toolPicker.addObserver(canvasView)
        
        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)
        
        DispatchQueue.main.async { [weak canvasView] in
            guard let canvasView, canvasView.window != nil else { return }
            canvasView.becomeFirstResponder()
            context.coordinator.toolPicker.setVisible(
                true,
                forFirstResponder: canvasView
            )
        }
        
        return scrollView
    }
    
    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        let coordinator = context.coordinator
        // 최초 updateUIView 시에는 아직 bounds가 0일 수 있어 레이아웃 이후 계산한다.
        DispatchQueue.main.async { [weak scrollView] in
            guard let scrollView, scrollView.window != nil else { return }
            let size = scrollView.bounds.size
            guard size.width > 0, size.height > 0,
                  let contentView = coordinator.contentView,
                  let imageView = coordinator.imageView else { return }
            
            if contentView.bounds.size != size {
                scrollView.setZoomScale(1, animated: false)
                contentView.frame = CGRect(origin: .zero, size: size)
                imageView.frame = contentView.bounds
                canvasView.frame = contentView.bounds
                scrollView.contentSize = size
                coordinator.centerContent(in: scrollView)
            }
            if imageView.image !== image {
                imageView.image = image
            }
        }
    }
    
    static func dismantleUIView(
        _ uiView: UIScrollView,
        coordinator: Coordinator
    ) {
        if let canvasView = coordinator.canvasView {
            coordinator.toolPicker.setVisible(false, forFirstResponder: canvasView)
            coordinator.toolPicker.removeObserver(canvasView)
        }
        uiView.delegate = nil
    }
    
    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var contentView: UIView?
        weak var imageView: UIImageView?
        weak var canvasView: PKCanvasView?
        
        let toolPicker: PKToolPicker = {
            let firstPen = PKToolPickerInkingItem(
                type: .pen, color: .white, width: 4
            )
            let secondPen = PKToolPickerInkingItem(
                type: .monoline, color: .white, width: 1
            )
            let highlighter = PKToolPickerInkingItem(
                type: .marker, color: .yellow, width: 8
            )
            let eraser = PKToolPickerEraserItem(type: .bitmap)
            let lasso = PKToolPickerLassoItem()
            let ruler = PKToolPickerRulerItem()
            return PKToolPicker(toolItems: [
                firstPen, secondPen, highlighter, eraser, lasso, ruler
            ])
        }()
        
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            contentView
        }
        
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerContent(in: scrollView)
        }
        
        func centerContent(in scrollView: UIScrollView) {
            guard let contentView else { return }
            let boundsSize = scrollView.bounds.size
            var frame = contentView.frame
            frame.origin.x = max((boundsSize.width - frame.width) / 2, 0)
            frame.origin.y = max((boundsSize.height - frame.height) / 2, 0)
            contentView.frame = frame
        }
        
        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView = gesture.view as? UIScrollView,
                  let contentView else { return }
            
            if scrollView.zoomScale > 1.01 {
                scrollView.setZoomScale(1, animated: true)
                return
            }
            
            let tapPoint = gesture.location(in: contentView)
            let targetScale: CGFloat = 2
            let zoomRect = CGRect(
                x: tapPoint.x - scrollView.bounds.width / (2 * targetScale),
                y: tapPoint.y - scrollView.bounds.height / (2 * targetScale),
                width: scrollView.bounds.width / targetScale,
                height: scrollView.bounds.height / targetScale
            )
            scrollView.zoom(to: zoomRect, animated: true)
        }
    }
}

#Preview {
    PhotoMarkupView(
        image: UIImage(systemName: "flame")!,
        onCancel: {},
        onSave: { _, _, _ in }
    )
}

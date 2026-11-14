// 직접 그리기에서 펜을 멈추면 그리던 획을 시작점에서 손가락까지의 직선으로 바꾼다
//
// PencilKit은 그리는 중인 획을 바꾸는 공개 기능이 없다. 그래서 멈춤을 알아채면 PencilKit의 그리기를 끊고
// 직선을 직접 그려 보여 주다가, 손을 떼면 직선 획을 그림에 넣는다

import PencilKit
import UIKit

/// 직선 보정 규칙
enum StraightStrokeRules {
    /// 이 시간(초) 동안 멈춰 있으면 직선으로 바꾼다
    // TEMP: 멈춤 시간은 실기기에서 정함
    static let holdDuration: TimeInterval = 0.5
    /// 이 범위(pt) 안에서만 움직이면 멈춘 것으로 본다
    // TEMP: 멈춤 범위는 실기기에서 정함
    static let holdRadius: CGFloat = 8
    /// 직선 위에 찍을 점 사이 (pt)
    static let pointSpacing: CGFloat = 4
    /// 이 각도(도)보다 덜 기울었으면 가로·세로로 맞춘다
    // TEMP: 맞춤 각도는 실기기에서 그려 보고 정함. 2D 수정 펜(StraightStrokeRules.snapAngle)과는 따로 둔다
    static let snapAngle = 2.0

    /// 시작점에서 끝점까지가 거의 가로·세로면 가로·세로로 맞춘 끝점을 돌려준다
    static func snappedEnd(from start: CGPoint, to end: CGPoint) -> CGPoint {
        let dx = end.x - start.x
        let dy = end.y - start.y
        guard dx != 0 || dy != 0 else { return end }
        let angle = atan2(abs(dy), abs(dx)) * 180 / .pi
        if angle < StraightStrokeRules.snapAngle { return CGPoint(x: end.x, y: start.y) }
        if angle > 90 - StraightStrokeRules.snapAngle { return CGPoint(x: start.x, y: end.y) }
        return end
    }
}

/// 캔버스에 붙여 두고 한 손가락의 움직임을 지켜보는 인식기. 터치를 가로채지 않아 PencilKit은 평소대로 그린다
final class StraightStrokeRecognizer: UIGestureRecognizer, UIGestureRecognizerDelegate {
    private weak var canvas: PKCanvasView?
    private var start = CGPoint.zero
    private var current = CGPoint.zero
    /// 이 자리에서 멈춘 시간을 잰다. 범위를 벗어나면 새 자리로 옮긴다
    private var anchor = CGPoint.zero
    private var holdTimer: Timer?
    private let previewLayer = CAShapeLayer()

    /// 방금 PencilKit이 그린 획의 점 모양(굵기·진하기·기울기). 직선 획이 다른 선과 똑같이 보이게 이걸 베껴 쓴다
    private var template: PKStrokePoint?

    /// 직선으로 바꾼 상태. 이때는 PencilKit의 그리기를 꺼 두었다
    private(set) var isStraightening = false
    /// 베낄 획이 아직 없어서(첫 획), 그리던 획은 그대로 두고 손을 뗀 뒤 그 획을 직선으로 바꾸기로 한 상태
    private var isDeferred = false

    init(canvas: PKCanvasView) {
        self.canvas = canvas
        super.init(target: nil, action: nil)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
        delegate = self
        previewLayer.fillColor = nil
        previewLayer.lineCap = .round
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard (event.allTouches?.count ?? 0) == 1, let touch = touches.first, let canvas else {
            finish(commit: false)
            return
        }
        // 그려 둔 마지막 획의 점 모양을 기억해 둔다
        template = canvas.drawing.strokes.last?.path.first ?? template
        start = touch.location(in: canvas)
        current = start
        anchor = start
        restartHoldTimer()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = touches.first, let canvas else { return }
        if (event.allTouches?.count ?? 0) > 1 {
            // 두 손가락이 닿으면 그리는 것이 아니다
            finish(commit: false)
            return
        }
        current = touch.location(in: canvas)
        if isStraightening {
            updatePreview()
        } else if hypot(current.x - anchor.x, current.y - anchor.y) > StraightStrokeRules.holdRadius {
            anchor = current
            restartHoldTimer()
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        finish(commit: true)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        finish(commit: false)
    }

    private func restartHoldTimer() {
        holdTimer?.invalidate()
        let timer = Timer(timeInterval: StraightStrokeRules.holdDuration, repeats: false) { [weak self] _ in
            self?.beginStraightening()
        }
        // 화면을 만지는 동안에도 울리도록 모든 실행 모드에 넣는다
        RunLoop.main.add(timer, forMode: .common)
        holdTimer = timer
    }

    private func beginStraightening() {
        guard let canvas, !isStraightening, !isDeferred else { return }
        // 베낄 획이 없으면 점 모양을 알 수 없다. 그리던 획을 그대로 두고 손을 뗀 뒤에 바꾼다
        guard template != nil else {
            isDeferred = true
            return
        }
        isStraightening = true
        // 그리던 획을 끊는다
        canvas.drawingGestureRecognizer.isEnabled = false
        if let tool = canvas.tool as? PKInkingTool {
            previewLayer.strokeColor = tool.color.cgColor
            previewLayer.lineWidth = template?.size.width ?? tool.width
        }
        canvas.layer.addSublayer(previewLayer)
        updatePreview()
    }

    private func updatePreview() {
        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: StraightStrokeRules.snappedEnd(from: start, to: current))
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer.path = path
        CATransaction.commit()
    }

    /// 손을 뗐거나 터치가 끊겼다. 직선으로 바꿨으면 commit일 때 직선 획을 넣는다
    private func finish(commit: Bool) {
        holdTimer?.invalidate()
        holdTimer = nil
        if isDeferred, commit, let canvas {
            // PencilKit이 획을 그림에 넣은 다음에 바꾼다
            let (start, end) = (start, StraightStrokeRules.snappedEnd(from: start, to: current))
            DispatchQueue.main.async { Self.replaceLastStroke(of: canvas, from: start, to: end) }
        }
        isDeferred = false
        if isStraightening, let canvas {
            previewLayer.removeFromSuperlayer()
            canvas.drawingGestureRecognizer.isEnabled = true
            if commit { addStraightStroke(to: canvas) }
        }
        isStraightening = false
        if state == .possible { state = .failed }
    }

    private func addStraightStroke(to canvas: PKCanvasView) {
        guard let tool = canvas.tool as? PKInkingTool, let template else { return }
        let end = StraightStrokeRules.snappedEnd(from: start, to: current)
        guard let stroke = Self.straightStroke(from: start, to: end, ink: tool.ink, like: template, offset: canvas.contentOffset) else { return }
        var drawing = canvas.drawing
        drawing.strokes.append(stroke)
        Self.replace(canvas, with: drawing)
    }

    /// 첫 획을 직선으로 바꾸려고 그리던 획을 그대로 뒀을 때: PencilKit이 넣은 마지막 획을 직선으로 갈아 끼운다.
    /// 되돌리기는 PencilKit이 그 획을 넣을 때 기록해 둔 것이 그대로 처리하므로 따로 기록하지 않는다
    private static func replaceLastStroke(of canvas: PKCanvasView, from start: CGPoint, to end: CGPoint) {
        var drawing = canvas.drawing
        guard let freehand = drawing.strokes.last, let point = freehand.path.first,
              let stroke = straightStroke(from: start, to: end, ink: freehand.ink, like: point, offset: canvas.contentOffset)
        else { return }
        drawing.strokes[drawing.strokes.count - 1] = stroke
        canvas.drawing = drawing
    }

    /// 시작점에서 끝점까지 점을 고르게 찍은 직선 획. 점 모양은 like를 베낀다
    private static func straightStroke(from start: CGPoint, to end: CGPoint, ink: PKInk, like template: PKStrokePoint, offset: CGPoint) -> PKStroke? {
        let length = hypot(end.x - start.x, end.y - start.y)
        guard length > 1 else { return nil }
        // 캔버스가 스크롤된 만큼 더해 그림 좌표로 바꾼다
        let count = max(Int(length / StraightStrokeRules.pointSpacing), 1)
        let points = (0...count).map { index -> PKStrokePoint in
            let t = CGFloat(index) / CGFloat(count)
            return PKStrokePoint(
                location: CGPoint(x: start.x + (end.x - start.x) * t + offset.x, y: start.y + (end.y - start.y) * t + offset.y),
                timeOffset: TimeInterval(index) * 0.01,
                size: template.size,
                opacity: template.opacity,
                force: template.force,
                azimuth: template.azimuth,
                altitude: template.altitude
            )
        }
        return PKStroke(ink: ink, path: PKStrokePath(controlPoints: points, creationDate: Date()))
    }

    /// 그림을 바꾸고 되돌리기에 기록한다. 되돌리는 쪽도 같은 함수로 다시 기록해 다시 하기도 된다
    private static func replace(_ canvas: PKCanvasView, with drawing: PKDrawing) {
        let previous = canvas.drawing
        canvas.undoManager?.registerUndo(withTarget: canvas) { replace($0, with: previous) }
        canvas.drawing = drawing
    }
}

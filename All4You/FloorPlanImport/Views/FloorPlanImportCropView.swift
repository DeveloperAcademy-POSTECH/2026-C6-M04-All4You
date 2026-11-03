import SwiftUI
import UIKit

struct FloorPlanImportCropView: View {
    let source: UIImage
    let onRetake: () -> Void
    let onConfirm: (UIImage) -> Void
    @State private var normalized: UIImage?
    // 화면 크기가 달라져도 같은 종이 영역을 유지한다.
    @State private var region = FloorPlanImportRegion()
    @State private var dragStart: [CGPoint]?
    @State private var processing = true
    @State private var message = "종이 영역을 찾고 있어요"
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button("다시 촬영", action: onRetake).disabled(processing)
                Spacer()
                Text("스캔 영역 조정").font(AppTypography.headlineEmphasized)
                Spacer()
                Button("사용하기") {
                    confirm()
                }
                .disabled(isConfirmDisabled)
            }.padding(16)
            GeometryReader { geometry in
                if let image = normalized {
                    let size = fitted(image.size, in: geometry.size)
                    ZStack {
                        Image(uiImage: image).resizable().frame(width: size.width, height: size.height)
                        paperOutline(in: size)
                            .stroke(.brand500, lineWidth: 4)
                        ForEach(0..<4, id: \.self) { index in
                            Circle().stroke(.brand500, lineWidth: 4)
                                .frame(width: 43, height: 43)
                                .contentShape(Rectangle()).position(point(index, in: size))
                                .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("crop"))
                                    .onChanged { value in
                                        if size.width <= 0 { return }
                                        if size.height <= 0 { return }
                                        if dragStart == nil {
                                            dragStart = region.corners
                                        }
                                        guard let start = dragStart else { return }
                                        var next = start
                                        // 손잡이를 잡은 위치와 관계없이 이동한 거리만큼 모서리를 옮긴다.
                                        let x = start[index].x + value.translation.width / size.width
                                        let y = start[index].y + value.translation.height / size.height
                                        next[index] = CGPoint(x: min(1, max(0, x)), y: min(1, max(0, y)))
                                        region.update(next)
                                    }
                                    .onEnded { _ in
                                        dragStart = nil
                                    })
                                .accessibilityLabel(["왼쪽 위", "오른쪽 위", "오른쪽 아래", "왼쪽 아래"][index] + " 모서리")
                        }
                    }.frame(width: size.width, height: size.height).coordinateSpace(name: "crop")
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                        .allowsHitTesting(processing == false)
                }
            }.padding(24)
            if processing {
                ProgressView()
            }
            Text(message).font(AppTypography.subheadline).padding(.bottom, 16)
        }.foregroundStyle(.white)
        .task {
            let prepared = await Task.detached { FloorPlanImportImageProcessor.prepare(source) }.value
            if Task.isCancelled {
                return
            }
            normalized = prepared.image
            if let detectedCorners = prepared.corners {
                region.update(detectedCorners)
                message = "주황색 모서리를 종이에 맞춘 뒤 사용하기를 눌러주세요"
            } else {
                message = "자동 인식하지 못했어요. 네 모서리를 종이에 맞춰주세요"
            }
            processing = false
        }
    }
    private var isConfirmDisabled: Bool {
        if processing {
            return true
        }
        if normalized == nil {
            return true
        }
        return false
    }

    private func paperOutline(in size: CGSize) -> Path {
        Path { path in
            path.move(to: point(0, in: size))
            for index in 1..<4 {
                path.addLine(to: point(index, in: size))
            }
            path.closeSubpath()
        }
    }

    private func point(_ index: Int, in size: CGSize) -> CGPoint {
        let corner = region.corners[index]
        return CGPoint(x: corner.x * size.width, y: corner.y * size.height)
    }

    private func fitted(_ image: CGSize, in container: CGSize) -> CGSize {
        let scale = min(container.width / image.width, container.height / image.height)
        return CGSize(width: image.width * scale, height: image.height * scale)
    }
    private func confirm() {
        guard let normalized else { return }
        processing = true
        let selected = region.corners
        Task {
            let output = await Task.detached { FloorPlanImportImageProcessor.correct(normalized, corners: selected) }.value
            processing = false
            if let correctedImage = output {
                onConfirm(correctedImage)
            } else {
                message = "보정할 수 없어요. 네 모서리를 다시 조정해주세요."
            }
        }
    }
}

#Preview("스캔 영역 조정") {
    // 에셋을 추가하지 않고 프리뷰용 종이 도면을 만든다.
    let sampleImage = UIGraphicsImageRenderer(size: CGSize(width: 1000, height: 750)).image { context in
        UIColor.darkGray.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 1000, height: 750))

        UIColor.white.setFill()
        context.fill(CGRect(x: 80, y: 60, width: 840, height: 630))

        UIColor.black.setStroke()
        let walls = UIBezierPath()
        walls.lineWidth = 3
        walls.append(UIBezierPath(rect: CGRect(x: 160, y: 140, width: 680, height: 470)))
        walls.append(UIBezierPath(rect: CGRect(x: 160, y: 140, width: 200, height: 180)))
        walls.append(UIBezierPath(rect: CGRect(x: 640, y: 140, width: 200, height: 180)))
        walls.stroke()

        let textStyle: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 34),
            .foregroundColor: UIColor.black
        ]
        ("주방" as NSString).draw(at: CGPoint(x: 220, y: 210), withAttributes: textStyle)
        ("방" as NSString).draw(at: CGPoint(x: 720, y: 210), withAttributes: textStyle)
        ("거실" as NSString).draw(at: CGPoint(x: 460, y: 440), withAttributes: textStyle)
    }

    FloorPlanImportCropView(
        source: sampleImage,
        onRetake: {},
        onConfirm: { _ in }
    )
    .background(.black)
    .preferredColorScheme(.dark)
}

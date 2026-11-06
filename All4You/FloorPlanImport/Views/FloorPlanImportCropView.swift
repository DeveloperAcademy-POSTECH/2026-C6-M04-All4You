import SwiftUI
import UIKit

struct FloorPlanImportCropView: View {
    let source: UIImage
    let onRetake: () -> Void
    let onConfirm: (UIImage) -> Void
    @State private var normalized: UIImage?
    @State private var region = FloorPlanImportRegion()
    @State private var dragStart: [CGPoint]?
    @State private var processing = true
    @State private var message = "종이 영역을 찾고 있어요"

    var body: some View {
        VStack {
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
                                        // 손잡이를 잡은 위치와 관계없이 이동한 거리만큼 모서리를 옮김
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
            }.padding(16)
            if processing {
                ProgressView()
            }
            Text(message).font(AppTypography.subheadline).padding(.bottom, 16)
        }
        .foregroundStyle(.primary)
        .navigationTitle("스캔 영역 조정")
        .navigationSubtitle("청암로 77") // TODO: 주소 불러온 걸로 바꾸기
        .navigationBarTitleDisplayMode(.inline)
        .bothSidesToolbar(
            leadingTitle: "뒤로 가기",
            trailingTitle: "저장",
            isDoneDisabled: isConfirmDisabled,
            customLayout: true,
            barTitle: "스캔 영역 조정",
            barSubtitle: "청암로 77", // TODO: 주소 불러온 걸로 바꾸기
            onBack: onRetake,
            onDone: confirm
        )
        .background(Color.white.ignoresSafeArea())
        .preferredColorScheme(.light)
        .task {
            let prepared = await Task.detached { FloorPlanImportImageProcessor.prepare(source) }.value
            if Task.isCancelled {
                return
            }
            normalized = prepared.image
            if let detectedCorners = prepared.corners {
                region.update(detectedCorners)
                message = "주황색 모서리를 종이에 맞춘 뒤 오른쪽 체크 버튼을 눌러주세요"
            } else {
                message = "자동 인식하지 못했어요. 네 모서리를 종이에 맞춰주세요"
            }
            processing = false
        }
    }
    // 사진을 처리 중이거나 사진 준비가 끝나지 않았다면 체크 버튼을 비활성화
    private var isConfirmDisabled: Bool {
        if processing {
            return true
        }
        if normalized == nil {
            return true
        }
        return false
    }

    // 현재 네 모서리를 연결해 스캔 영역의 테두리를 그림
    private func paperOutline(in size: CGSize) -> Path {
        Path { path in
            path.move(to: point(0, in: size))
            for index in 1..<4 {
                path.addLine(to: point(index, in: size))
            }
            path.closeSubpath()
        }
    }

    // 0...1로 저장한 모서리 좌표를 화면에 표시할 실제 위치로 바꿈
    private func point(_ index: Int, in size: CGSize) -> CGPoint {
        let corner = region.corners[index]
        return CGPoint(x: corner.x * size.width, y: corner.y * size.height)
    }

    // 사진 비율을 유지하면서 주어진 화면 안에 들어가는 표시 크기 계산
    private func fitted(_ image: CGSize, in container: CGSize) -> CGSize {
        let scale = min(container.width / image.width, container.height / image.height)
        return CGSize(width: image.width * scale, height: image.height * scale)
    }
    // 선택한 영역을 원근 보정하고 완성 이미지를 상위 화면에 전달
    private func confirm() {
        guard !isConfirmDisabled, let normalized else { return }
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

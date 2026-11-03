import SwiftUI

struct FloorPlanImportView: View {
    var onImport: ((UIImage) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = FloorPlanImportCamera()
    @Environment(\.scenePhase) private var scenePhase
    @State private var source: UIImage?
    @State private var result: UIImage?

    var body: some View {
        NavigationStack {
            content
                .navigationBarTitleDisplayMode(.inline)
                .backOnlyToolbar(title: "목록으로") {
                    camera.stop()
                    dismiss()
                }
        }
    }

    private var content: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let result {
                VStack(spacing: 20) {
                    Text("스캔 결과 확인").font(AppTypography.title2Emphasized)
                    Image(uiImage: result).resizable().scaledToFit().padding(16)
                    HStack(spacing: 24) {
                        if let onImport {
                            Button("이 도면 사용") {
                                onImport(result)
                                dismiss()
                            }
                        }
                        Button("다시 촬영") { reset() }
                        ShareLink(item: Image(uiImage: result), preview: SharePreview("평면도 스케치", image: Image(uiImage: result))) {
                            Label("이미지 내보내기", systemImage: "square.and.arrow.up")
                        }
                    }.buttonStyle(.borderedProminent)
                }.padding(16).foregroundStyle(.white)
            } else if let source {
                FloorPlanImportCropView(source: source, onRetake: reset) { correctedImage in
                    result = correctedImage
                }
            } else {
                captureScreen
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: camera.image) { _, capturedImage in
            if let capturedImage = capturedImage {
                source = capturedImage
            }
        }
    }

    private var captureScreen: some View {
        GeometryReader { geometry in
            let landscape = geometry.size.width > geometry.size.height
            // 카메라 화면의 왼쪽 위를 기준으로 한 가이드 위치와 크기.
            let guideSize = CGSize(width: 1069, height: 836)
            ZStack {
                FloorPlanImportCameraPreview(camera: camera)
                RoundedRectangle(cornerRadius: 24)
                    .stroke(.white, lineWidth: 4)
                    .frame(width: guideSize.width, height: guideSize.height)
                    .onGeometryChange(for: [CGRect].self) { frame in
                        [frame.frame(in: .named("scanPreview")), CGRect(origin: .zero, size: geometry.size)]
                    } action: { frames in
                        camera.updateGuide(previewSize: frames[1].size, guide: frames[0])
                    }
                    .padding(.bottom, 99)
                    .padding(.leading, 138)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .allowsHitTesting(false)
                VStack {
                    Spacer()
                    Text(camera.message).font(.callout)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 18).padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.horizontal, 80).padding(.bottom, 110)
                }
                HStack {
                    zoomButtons
                        .padding(.leading, 27)
                    Spacer()
                    if landscape {
                        shutter.padding(.trailing, 24)
                    }
                }
                if landscape == false {
                    VStack {
                        Spacer()
                        shutter.padding(.bottom, 20)
                    }
                }
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        if camera.detected {
                            Label("종이 인식됨", systemImage: "checkmark.viewfinder").font(AppTypography.label).foregroundStyle(.yellow)
                        }
                    }.padding(18)
                }
            }
            .coordinateSpace(name: "scanPreview")
            .foregroundStyle(.white)
            .onAppear {
                camera.start()
            }
            .onDisappear {
                camera.stop()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    camera.start()
                } else {
                    camera.stop()
                }
            }
        }
    }
    private var zoomButtons: some View {
        VStack(spacing: 12) {
            ForEach([0.5, 1.0, 2.0, 3.0], id: \.self) { value in
                Button {
                    camera.setZoom(value)
                } label: {
                    Text(value.formatted() + "×")
                        .font(AppTypography.label.weight(.bold))
                        .foregroundStyle(zoomColor(for: value))
                        .frame(width: 44, height: 44)
                        .background(.black.opacity(0.4), in: Circle())
                }
                .disabled(isZoomDisabled(value))
            }
        }
    }

    private func zoomColor(for value: Double) -> Color {
        if camera.zoom == value {
            return .yellow
        }
        return .white
    }

    private func isZoomDisabled(_ value: Double) -> Bool {
        if isCaptureDisabled {
            return true
        }
        if value == 0.5 {
            if camera.supportsHalfZoom == false {
                return true
            }
        }
        return false
    }

    private var shutter: some View {
        Button { camera.capture() } label: {
            ZStack {
                Image(systemName: "shutter")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 102, height: 102)
                    .foregroundStyle(.white)
                if camera.busy {
                    ProgressView().tint(.black)
                }
            }
            .padding(.horizontal, 27)
        }
        .disabled(isCaptureDisabled)
        .accessibilityLabel("도면 직접 스캔")
    }
    private var isCaptureDisabled: Bool {
        // 카메라가 준비되기 전에는 촬영할 수 없다.
        if camera.ready == false {
            return true
        }
        // 이미 촬영 중이라면 다시 누를 수 없다.
        if camera.busy {
            return true
        }
        return false
    }

    private func reset() {
        source = nil
        result = nil
        camera.image = nil
        // 촬영 화면이 다시 나타나면 onAppear에서 카메라를 시작한다.
    }
}

#Preview {
    FloorPlanImportView()
}

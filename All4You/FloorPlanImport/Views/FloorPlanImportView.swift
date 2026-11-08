import SwiftUI

struct FloorPlanImportView: View {
    var onImport: ((UIImage) -> Void)? = nil
    var address = "청암로 77"
    var onBack: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = FloorPlanImportCamera()
    @Environment(\.scenePhase) private var scenePhase
    @State private var source: UIImage?
    @State private var result: UIImage?

    var body: some View {
        NavigationStack {
            if let result {
                scanResult(image: result)
            } else {
                content
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    // 보정된 도면을 화면에 최대한 크게 표시. 도면이 잘리지 않도록 비율 유지
    private func scanResult(image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.white)
            .preferredColorScheme(.light)
            .navigationTitle("스캔 결과 확인")
            .navigationSubtitle(address)
            .navigationBarTitleDisplayMode(.inline)
            .bothSidesToolbar(
                leadingTitle: "뒤로 가기",
                trailingTitle: "저장",
                customLayout: true,
                barTitle: "스캔 결과 확인",
                barSubtitle: address,
                onBack: {
                    // 원본 사진은 유지하고 결과만 비워 영역 조정 화면으로 돌아간다.
                    result = nil
                },
                onDone: {
                    if let onImport {
                        onImport(image)
                    }
                    dismiss()
                }
            )
    }

    // 촬영한 원본이 있으면 모서리 조정 화면을, 없으면 카메라를 표시
    private var content: some View {
        Group {
            if let source {
                FloorPlanImportCropView(source: source, address: address, onRetake: reset) { correctedImage in
                    result = correctedImage
                }
            } else {
                ZStack {
                    Color.black.ignoresSafeArea()
                    captureScreen
                }
                .toolbar(.hidden, for: .navigationBar)
                // 미리보기보다 앞에 버튼을 배치해 터치를 받도록 한다.
                .overlay(alignment: .topLeading) {
                    Button {
                        if let onBack {
                            onBack()
                        } else {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(width: 44, height: 44)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .accessibilityLabel("뒤로 가기")
                    .padding(.leading, 32)
                    .padding(.top, 16)
                }
                .preferredColorScheme(.dark)
            }
        }
        .onChange(of: camera.image) { _, capturedImage in
            if let capturedImage = capturedImage {
                source = capturedImage
            }
        }
    }

    // 카메라 화면을 구성하고, 화면이 나타나거나 사라질 때 카메라를 켜고 끔
    private var captureScreen: some View {
        GeometryReader { geometry in
            let landscape = geometry.size.width > geometry.size.height

            ZStack {
                FloorPlanImportCameraPreview(camera: camera)
                    .allowsHitTesting(false)
                guideFrame(previewSize: geometry.size)
                captureHint
                captureControls(landscape: landscape)
                detectionStatus
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
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
        // 카메라와 인식 좌표를 모두 화면 전체 크기에 맞춤
        .ignoresSafeArea()
    }

    // 화면 가장자리에서 여백을 준 흰색 프레임. 실제 위치를 자동 촬영 기준으로 전달
    private func guideFrame(previewSize: CGSize) -> some View {
        RoundedRectangle(cornerRadius: 24)
            .stroke(.white, lineWidth: 4)
            .onGeometryChange(for: CGRect.self) { frame in
                frame.frame(in: .named("scanPreview"))
            } action: { frame in
                camera.updateGuide(previewSize: previewSize, guide: frame)
            }
            .padding(.top, 90)
            .padding(.bottom, 99)
            .padding(.leading, 138)
            .padding(.trailing, 159)
            .allowsHitTesting(false)
    }

    // 화면 아래에 현재 촬영 안내 문구를 표시
    private var captureHint: some View {
        VStack {
            Spacer()
            Text(camera.message)
                .font(.callout)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 26)
                .padding(.vertical, 8)
                .glassEffect((.regular), in: Capsule())
                .padding(.bottom, 39)
        }
    }

    // 배율 버튼은 왼쪽에, 촬영 버튼은 가로 화면에서 오른쪽, 세로 화면에서 아래에 배치
    private func captureControls(landscape: Bool) -> some View {
        ZStack {
            HStack {
                zoomButtons
                    .padding(.leading, 32)
                Spacer()
                if landscape {
                    shutter.padding(.trailing, 27)
                }
            }
            if landscape == false {
                VStack {
                    Spacer()
                    shutter.padding(.bottom, 20)
                }
            }
        }
    }

    // 종이가 인식되면 오른쪽 아래에 인식 상태를 표시
    private var detectionStatus: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                if camera.detected {
                    Label("종이 인식됨", systemImage: "checkmark.circle")
                        .font(AppTypography.label)
                        .foregroundStyle(.yellow)
                }
            }
            .padding(18)
        }
    }

    // 0.5배, 1배, 2배, 3배 버튼을 표시하고 선택한 배율을 카메라에 전달
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

    // 현재 선택한 배율은 노란색, 나머지는 흰색으로 표시
    private func zoomColor(for value: Double) -> Color {
        if camera.zoom == value {
            return .yellow
        }
        return .white
    }

    // 촬영할 수 없는 상태이거나 지원하지 않는 배율이면 줌 버튼을 비활성화
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

    // 누르면 직접 촬영하는 흰색 원형 버튼
    private var shutter: some View {
        Button { camera.capture() } label: {
            ZStack {
                Circle()
                    .strokeBorder(.white, lineWidth: 4)
                    .frame(width: 102, height: 102)
                Circle()
                    .fill(.white)
                    .frame(width: 85, height: 85)
                if camera.busy {
                    ProgressView().tint(.black)
                }
            }
        }
        .disabled(isCaptureDisabled)
        .accessibilityLabel("도면 직접 스캔")
    }
    // 카메라 준비 전이거나 이미 촬영 중이면 촬영 버튼을 비활성화
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
    }
}

#Preview {
    FloorPlanImportView()
}

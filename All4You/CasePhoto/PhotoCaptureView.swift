//
//  PhotoCaptureView.swift
//  All4You
//
//  Created by SIA on 11/9/26.
//

// 사진 촬영 화면. 카메라 화면 위에 뒤로가기·촬영 종료·셔터가 있고, 찍은 사진은 아래 띠에 쌓인다

import SwiftUI

/// 사진을 여러 장 찍는 화면. 찍은 사진은 바로 저장소에 들어가 위치 미지정 사진이 된다
struct PhotoCaptureView: View {
    let store: PhotoStore
    /// 뒤로가기·촬영 종료를 누르면 화면을 닫는다
    let onClose: () -> Void

    @State private var camera = PhotoCaptureCamera()
    /// 이 화면에서 찍은 사진 (찍은 순서). 사진 보기에서 지우면 저장소에서 사라져 띠에서도 빠진다
    @State private var capturedIDs: [UUID] = []
    @State private var isCapturing = false
    /// 셔터를 누르면 잠깐 하얗게 번쩍인다
    @State private var isFlashing = false
    /// 띠에서 누른 사진. 값이 있으면 사진 보기가 뜬다
    @State private var viewerContext: PhotoViewerContext?

    private var capturedPhotos: [LoadedPhoto] {
        capturedIDs.compactMap(store.photo(id:))
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            if camera.isAvailable {
                CameraPreview(camera: camera)
                    .ignoresSafeArea()
            } else {
                unavailableMessage
            }
            Color.white
                .ignoresSafeArea()
                .opacity(isFlashing ? Layout.flashOpacity : 0)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .topLeading) {
            backButton
                .padding(Layout.edgePadding)
        }
        .overlay(alignment: .topTrailing) {
            finishButton
                .padding(Layout.edgePadding)
        }
        .overlay(alignment: .trailing) {
            shutterButton
                .padding(.trailing, Layout.edgePadding)
        }
        .overlay(alignment: .bottom) {
            if !capturedPhotos.isEmpty {
                PhotoThumbnailStrip(photos: capturedPhotos, selectedID: nil) { id in
                    viewerContext = PhotoViewerContext(photoIDs: capturedIDs, initialID: id)
                }
            }
        }
        .statusBarHidden()
        .onAppear(perform: camera.start)
        .onDisappear(perform: camera.stop)
        .fullScreenCover(item: $viewerContext) { context in
            PhotoDetailView(store: store, context: context) {
                viewerContext = nil
            }
        }
        // 사진 보기가 떠 있는 동안은 카메라를 쉬게 한다
        .onChange(of: viewerContext == nil) { _, isCameraVisible in
            if isCameraVisible {
                camera.start()
            } else {
                camera.stop()
            }
        }
    }
}

// 서브 뷰
extension PhotoCaptureView {
    private var backButton: some View {
        GlassCircleButton(title: Copy.back, systemImage: "chevron.left", action: onClose)
    }

    // TEMP: Figma에서 뒤로가기와 촬영 종료가 하는 일이 나뉘어 있지 않아 둘 다 화면을 닫음 — 찍은 사진은 이미 저장돼 있음. 팀 확인 필요
    private var finishButton: some View {
        Button(action: onClose) {
            Text(Copy.finish)
                .font(AppTypography.subheadlineEmphasized)
                .padding(.horizontal, Layout.finishPadding)
                .frame(height: Layout.finishHeight)
        }
        .buttonStyle(.glassProminent)
        .tint(.red)
    }

    /// 흰 원과 바깥 흰 테두리로 된 셔터
    private var shutterButton: some View {
        Button(action: takePhoto) {
            Circle()
                .fill(.white)
                .padding(Layout.shutterRingGap)
                .overlay {
                    Circle()
                        .strokeBorder(.white, lineWidth: Layout.shutterRingWidth)
                }
                .frame(width: Layout.shutterSize, height: Layout.shutterSize)
                .shadow(radius: Layout.shutterShadowRadius)
        }
        .buttonStyle(.plain)
        .disabled(isCapturing || !camera.isAvailable)
        .accessibilityLabel(Copy.shutter)
    }

    private var unavailableMessage: some View {
        ContentUnavailableView(Copy.unavailableTitle, systemImage: "camera.badge.ellipsis", description: Text(Copy.unavailableMessage))
            .foregroundStyle(.white)
    }
}

// 촬영
extension PhotoCaptureView {
    // TODO: 촬영 위치(위치 권한)·도면 위 위치를 함께 남겨 장소를 자동 지정하기 (Figma "사진 자동 지정")
    private func takePhoto() {
        isCapturing = true
        flash()
        Task {
            defer { isCapturing = false }
            guard let photo = await camera.capturePhoto() else { return }
            let id = store.add(image: photo.image, thumbnail: photo.thumbnail, takenAt: .now, source: .camera)
            withAnimation {
                capturedIDs.append(id)
            }
        }
    }

    private func flash() {
        isFlashing = true
        withAnimation(.easeOut(duration: Layout.flashDuration)) {
            isFlashing = false
        }
    }
}

// 크기
extension PhotoCaptureView {
    private enum Layout {
        static let edgePadding: CGFloat = 24
        static let finishHeight: CGFloat = 36
        static let finishPadding: CGFloat = 6
        static let shutterSize: CGFloat = 92
        static let shutterRingWidth: CGFloat = 4
        static let shutterRingGap: CGFloat = 8
        static let shutterShadowRadius: CGFloat = 4
        static let flashOpacity: CGFloat = 0.8
        static let flashDuration: Double = 0.25
    }
}

// 문구
extension PhotoCaptureView {
    private enum Copy {
        static let back = "뒤로"
        static let finish = "촬영 종료"
        static let shutter = "사진 찍기"
        // TEMP: Figma에 카메라를 쓸 수 없을 때의 화면이 없어 임의로 작성한 문구
        static let unavailableTitle = "카메라를 사용할 수 없어요"
        static let unavailableMessage = "이 기기에서는 카메라를 찾을 수 없어요."
    }
}

#Preview {
    PhotoCaptureView(store: PhotoStore(), onClose: {})
}

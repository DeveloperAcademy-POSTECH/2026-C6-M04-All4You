//
//  RoomPlanScanView.swift
//  All4You
//
//  Created by 채유성 on 11/1/26.
//

import AVFoundation
import RoomPlan
import SwiftUI

// 카메라 권한과 스캔 상태를 바탕으로 RoomPlan 카메라, 구간 미리보기, 촬영 안내 및 제어 화면을 구성하는 진입 뷰
struct RoomPlanScanView: View {
    @State private var scanID = UUID()
    @State private var skipChecklistOnRescan = false
    @State private var rescanBackdrop: UIImage?
    /// 스캔 결과: usdz 파일, 여러 구간을 합친 구조(구간이 2개 이상일 때만), 구간별 결과
    /// 마지막 값: 스캔 중 찍은 사진(카메라 자세 포함)
    let onUseResult: ((URL, CapturedStructure?, [CapturedRoom], [ScanPhoto]) -> Void)?

    init(onUseResult: ((URL, CapturedStructure?, [CapturedRoom], [ScanPhoto]) -> Void)? = nil) {
        self.onUseResult = onUseResult
    }

    var body: some View {
        RoomPlanScanSessionView(
            skipsChecklist: skipChecklistOnRescan,
            initialBackdrop: rescanBackdrop,
            onUseResult: onUseResult,
            onCameraReady: { rescanBackdrop = nil },
            onRescan: { snapshot in
                // 재스캔은 새 세션으로 시작하되 최초 확인 사항은 다시 표시하지 않음
                rescanBackdrop = snapshot
                skipChecklistOnRescan = true
                scanID = UUID()
            }
        )
        .id(scanID)
    }
}

private struct RoomPlanScanSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var finishedCameraSnapshot: UIImage?
    @State private var isCameraPreviewReady = false
    @State private var isSegmentAlertPresented = false
    @State private var segmentAlertTask: Task<Void, Never>?
    @StateObject private var scanService = RoomPlanScanService()
    let skipsChecklist: Bool
    let initialBackdrop: UIImage?
    let onUseResult: ((URL, CapturedStructure?, [CapturedRoom], [ScanPhoto]) -> Void)?
    let onCameraReady: () -> Void
    let onRescan: (UIImage?) -> Void

    var body: some View {
        ZStack {
            if scanService.phase == .finished, let finishedCameraSnapshot {
                GeometryReader { geometry in
                    Image(uiImage: finishedCameraSnapshot)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .accessibilityHidden(true)
                }
                .ignoresSafeArea()
            } else if let initialBackdrop {
                Image(uiImage: initialBackdrop)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
            } else {
                Color(.secondarySystemBackground).ignoresSafeArea()
            }

            if scanService.phase == .finished {
                Color.black.opacity(0.35).ignoresSafeArea()
                ScanPreviewSheet(
                    rooms: scanService.finishedRooms,
                    structure: scanService.mergedPreview,
                    revision: scanService.renderRevision,
                    isContinueEnabled: scanService.finalModelURL != nil && onUseResult != nil,
                    statusMessage: scanService.mergeError,
                    onContinue: {
                        guard let url = scanService.finalModelURL else { return }
                        onUseResult?(url, scanService.mergedPreview, scanService.finishedRooms, scanService.scanPhotos)
                    },
                    onChooseOtherMethod: {
                        scanService.detach()
                        dismiss()
                    },
                    onRescan: {
                        if finishedCameraSnapshot == nil { captureFinishedCameraFrame() }
                        scanService.detach()
                        onRescan(finishedCameraSnapshot)
                    }
                )
            } else if cameraStatus == .authorized && RoomCaptureSession.isSupported {
                // 촬영 전과 일시정지 중 공유 ARSession의 카메라 영상 유지
                RoomPlanCameraPreview(
                    arSession: scanService.arSession,
                    isActive: scanService.phase != .scanning || !isCameraPreviewReady,
                    onFirstFrameRendered: { [renderedSession = scanService.arSession] in
                        // 새 AR 세션의 첫 영상이 화면에 그려진 뒤 종료 시점의 정지 화면 제거
                        guard scanService.arSession === renderedSession else { return }
                        isCameraPreviewReady = true
                        onCameraReady()
                        if scanService.isRelocalizing { finishedCameraSnapshot = nil }
                    }
                )
                .id(scanService.segmentID)
                .ignoresSafeArea()
                .allowsHitTesting(false)

                // 촬영 중에만 기본 RoomPlan 화면 노출 및 중지 화면의 회색 배경 차단
                RoomPlanCameraSurface(scanService: scanService)
                    .id(scanService.segmentID)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .opacity(scanService.phase == .scanning ? 1 : 0)

                // 자동 종료 순간의 카메라 프레임을 저장·확인 화면 뒤에 고정
                if isFrozenLimitBackground, let finishedCameraSnapshot {
                    GeometryReader { geometry in
                        Image(uiImage: finishedCameraSnapshot)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                    }
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }

                if !isCameraPreviewReady {
                    if let initialBackdrop {
                        GeometryReader { geometry in
                            Image(uiImage: initialBackdrop)
                                .resizable()
                                .scaledToFill()
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .clipped()
                        }
                        .ignoresSafeArea()
                        .accessibilityHidden(true)
                    } else {
                        Color(.secondarySystemBackground).ignoresSafeArea()
                    }
                }

                // 일시정지 및 촬영 종료 확인창에서 하단 도면 미리보기 유지
                if !displayedPreviewRooms.isEmpty {
                    RoomPlanScanThumbnailView(
                        rooms: displayedPreviewRooms,
                        structure: scanService.isMergingPreview ? nil : scanService.mergedPreview,
                        liveRoom: nil,
                        revision: scanService.renderRevision
                    )
                    .frame(width: 520, height: 390)
                    .padding(.bottom, 32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .allowsHitTesting(false)
                }

                // 촬영 단계별 확인사항·제어·저장·완료 화면 분기
                switch scanService.phase {
                case .checklist:
                    if skipsChecklist {
                        Color.clear
                            .task { scanService.prepare() }
                    } else {
                        Color.black.opacity(0.35).ignoresSafeArea()
                        ScrollView {
                            PreScanInfo { scanService.prepare() }
                                .padding(24)
                                .frame(maxWidth: .infinity)
                        }
                        .defaultScrollAnchor(.center)
                    }
                case .ready, .scanning, .paused:
                    RoomPlanScanOverlay(
                        phase: scanService.phase,
                        guidance: scanService.guidance,
                        pauseStatus: pauseStatus,
                        isTorchOn: scanService.isTorchOn,
                        torchMessage: scanService.torchMessage,
                        onStart: scanService.begin,
                        onStop: {
                            if finishedCameraSnapshot == nil { captureFinishedCameraFrame() }
                            scanService.stop()
                        },
                        onPause: scanService.pause,
                        onTorch: scanService.toggleTorch,
                        photoCount: scanService.scanPhotoCount,
                        canCapturePhoto: scanService.canCapturePhoto,
                        photoMessage: scanService.photoMessage,
                        onCapturePhoto: { scanService.capturePhoto(orientation: currentInterfaceOrientation) }
                    )
                    // TODO: 디자인 나오면 수정해야함
                case .saving:
                    if isLimitIssue {
                        RoomPlanLimitGuidance(stage: .saving)
                    } else {
                        ProgressView("스캔 구간 저장 중…")
                            .tint(.white)
                            .foregroundStyle(.white)
                            .padding(24)
                            .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 16))
                    }
                case .segmentSaved:
                    if scanService.isRelocalizing {
                        ProgressView("이전 스캔 위치를 찾는 중…")
                            .tint(.white)
                            .foregroundStyle(.white)
                            .padding(24)
                            .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 16))
                    } else if isLimitIssue && !isSegmentAlertPresented {
                        RoomPlanLimitGuidance(stage: .saved)
                    } else if scanService.isMergingPreview && !scanService.isScanLimitReached {
                        ProgressView("도면 정리 중…")
                            .tint(.white)
                            .foregroundStyle(.white)
                            .padding(24)
                            .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 16))
                    }
                case .finished:
                    EmptyView()
                }
            } else {
                ContentUnavailableView(
                    !RoomCaptureSession.isSupported ? "공간 스캔을 지원하지 않는 기기입니다" :
                        cameraStatus == .notDetermined ? "카메라 권한을 확인하는 중입니다" : "공간 스캔을 위한 카메라 접근이 필요합니다",
                    systemImage: "camera",
                    description: Text(!RoomCaptureSession.isSupported
                                      ? "LiDAR를 지원하는 iPhone 또는 iPad에서 실행해 주세요."
                                      : cameraStatus == .notDetermined
                                      ? "카메라 권한을 확인하고 있습니다."
                                      : "설정 → 앱 → FireLine에서 카메라 접근을 허용해 주세요.")
                )
                .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.container, edges: .all)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(scanService.phase == .finished ? .hidden : .visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .backOnlyToolbar(title: "이전") {
            scanService.detach()
            dismiss()
        }
        .alert(
            RoomPlanSegmentDialog.title,
            isPresented: $isSegmentAlertPresented
        ) {
            Button("스캔 마치기", role: .cancel) {
                if finishedCameraSnapshot == nil { captureFinishedCameraFrame() }
                scanService.finish()
            }
            Button("계속 스캔") {
                scanService.continueScanning()
                // 위치 복원 준비에 실패하면 촬영 종료 또는 재시도 선택지를 다시 표시
                if scanService.phase == .segmentSaved && !scanService.isRelocalizing {
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(350))
                        isSegmentAlertPresented = true
                    }
                }
            }
        } message: {
            Text(RoomPlanSegmentDialog.message)
        }
        .onChange(of: scanService.phase) { _, phase in
            segmentAlertTask?.cancel()
            if phase == .ready { finishedCameraSnapshot = nil }
            if phase == .segmentSaved { scheduleSegmentAlert() }
        }
        .onChange(of: scanService.isRelocalizing) { _, isRelocalizing in
            if !isRelocalizing && scanService.phase == .segmentSaved {
                scheduleSegmentAlert()
            }
        }
        .onAppear { scanService.onAutomaticStop = captureFinishedCameraFrame }
        .onDisappear {
            segmentAlertTask?.cancel()
            scanService.onAutomaticStop = nil
            scanService.detach()
        }
        // 앱 최초 진입 및 앱 활성화 시 카메라 권한 상태 재확인
        .task {
            await refreshCameraPermission()
        }
        .onChange(of: scenePhase) { _, phase in
            // 제어 센터를 내리거나 알림이 왔을 경우 및 백그라운드 전환에서는 스캔 단계와 세션 유지
            guard phase == .active else { return }
            Task { await refreshCameraPermission() }
        }
    }

    // 시스템 카메라 권한 확인 및 최초 접근 요청
    private func refreshCameraPermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            cameraStatus = granted ? .authorized : AVCaptureDevice.authorizationStatus(for: .video)
        } else {
            cameraStatus = status
        }
    }

    private var isLimitIssue: Bool {
        scanService.issue == .scanTimeLimitReached || scanService.issue == .sceneLimitReached
    }

    private var isFrozenLimitBackground: Bool {
        scanService.isScanLimitReached && finishedCameraSnapshot != nil
        && (scanService.phase == .saving || scanService.phase == .segmentSaved)
    }

    // 저장 완료 안내를 읽을 시간을 준 다음 구간 계속 여부를 확인
    private func scheduleSegmentAlert() {
        segmentAlertTask?.cancel()
        guard !scanService.isRelocalizing else { return }
        guard scanService.isScanLimitReached else { return }
        guard isLimitIssue else {
            isSegmentAlertPresented = true
            return
        }
        segmentAlertTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled,
                  scanService.phase == .segmentSaved,
                  !scanService.isRelocalizing else { return }
            isSegmentAlertPresented = true
        }
    }

    // 종료 버튼을 누른 시점의 AR 카메라 사진을 저장하여 완료 화면 뒤에 배치
    private func captureFinishedCameraFrame() {
        guard finishedCameraSnapshot == nil else { return }
        finishedCameraSnapshot = RoomPlanCameraSnapshot.capture(
            from: scanService.arSession,
            orientation: currentInterfaceOrientation
        ) ?? finishedCameraSnapshot
    }

    // 카메라 픽셀 버퍼를 화면 방향에 맞게 돌릴 때 쓰는 현재 화면 방향
    private var currentInterfaceOrientation: UIInterfaceOrientation {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .effectiveGeometry.interfaceOrientation ?? .landscapeRight
    }

    // 예외처리 - 일시정지 구간의 저장·병합 진행 상태 문구
    // TODO: 합의 필요
    private var pauseStatus: String? {
        guard scanService.phase == .paused else { return nil }
        if scanService.isSavingPause { return "스캔 상태 저장 중…" }
        if scanService.isMergingPreview { return "촬영한 방을 병합하는 중…" }
        if case .saveFailed = scanService.issue { return "스캔 상태를 저장하지 못했습니다" }
        return "스캔 상태 저장됨"
    }

    // 스캔 종료 확인 시점에는 최종 스캔된 결과만 전달해 직전 RoomPlan 스캔 결과와 겹치는 현상 방지
    private var displayedPreviewRooms: [CapturedRoom] {
        switch scanService.phase {
        case .paused:
            scanService.previewRooms
        case .segmentSaved:
            scanService.finishedRooms
        default:
            []
        }
    }

}

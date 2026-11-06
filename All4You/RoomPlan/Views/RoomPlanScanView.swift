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
    let onUseResult: ((URL) -> Void)?
    
    init(onUseResult: ((URL) -> Void)? = nil) {
        self.onUseResult = onUseResult
    }
    
    var body: some View {
        RoomPlanScanSessionView(
            skipsChecklist: skipChecklistOnRescan,
            onUseResult: onUseResult,
            onRescan: {
                // 재스캔은 새 세션으로 시작하되 최초 확인 사항은 다시 표시하지 않음
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
    @StateObject private var scanService = RoomPlanScanService()
    let skipsChecklist: Bool
    let onUseResult: ((URL) -> Void)?
    let onRescan: () -> Void
    
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
            } else {
                Color.black.ignoresSafeArea()
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
                        onUseResult?(url)
                    },
                    onChooseOtherMethod: {
                        scanService.detach()
                        dismiss()
                    },
                    onRescan: {
                        scanService.detach()
                        onRescan()
                    }
                )
            } else if cameraStatus == .authorized && RoomCaptureSession.isSupported {
                // 촬영 전과 일시정지 중 공유 ARSession의 카메라 영상 유지
                RoomPlanCameraPreview(
                    arSession: scanService.arSession,
                    isActive: scanService.phase != .scanning
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
                            captureFinishedCameraFrame()
                            scanService.stop()
                        },
                        onPause: scanService.pause,
                        onTorch: scanService.toggleTorch
                    )
                    // TODO: 디자인 나오면 수정해야함
                case .saving:
                    ProgressView("스캔 구간 저장 중…")
                        .tint(.white)
                        .foregroundStyle(.white)
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                case .segmentSaved:
                    if scanService.isRelocalizing {
                        ProgressView("이전 스캔 위치를 찾는 중…")
                            .tint(.white)
                            .foregroundStyle(.white)
                            .padding(24)
                            .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 16))
                    } else {
                        RoomPlanSegmentDialog(
                            issue: scanService.issue,
                            savedCount: scanService.savedSegments.count,
                            onFinish: {
                                captureFinishedCameraFrame()
                                scanService.finish()
                            },
                            onContinue: {
                                finishedCameraSnapshot = nil
                                scanService.continueScanning()
                            }
                        )
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
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .topLeading) {
            if scanService.phase != .finished {
                Button {
                    scanService.detach()
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.glass)
                .padding(16)
                .accessibilityLabel("이전")
            }
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
    
    // 종료 버튼을 누른 시점의 AR 카메라 사진을 저장하여 완료 화면 뒤에 배치
    private func captureFinishedCameraFrame() {
        let orientation = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .effectiveGeometry.interfaceOrientation ?? .landscapeRight
        finishedCameraSnapshot = RoomPlanCameraSnapshot.capture(
            from: scanService.arSession,
            orientation: orientation
        ) ?? finishedCameraSnapshot
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

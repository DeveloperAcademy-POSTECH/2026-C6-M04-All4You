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
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @StateObject private var scanService = RoomPlanScanService()
    
    var body: some View {
        // 권한 확인 후 카메라 계층, 구간 미리보기, phase별 오버레이를 합성하는 화면 흐름
        ZStack {
            Color.black.ignoresSafeArea()
            
            if cameraStatus == .authorized && RoomCaptureSession.isSupported {
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
                
                // 저장된 방 또는 중간 병합 구조의 화면 하단 미리보기
                if scanService.phase == .paused, !scanService.previewRooms.isEmpty {
                    RoomPlanScanThumbnailView(
                        rooms: scanService.previewRooms,
                        structure: scanService.isMergingPreview ? nil : scanService.mergedPreview,
                        liveRoom: nil,
                        revision: scanService.renderRevision
                    )
                    .frame(width: 520, height: 390)
                    .padding(.bottom, 32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .allowsHitTesting(false)
                }
                
                // 촬영 단계별 확인 사항·제어·저장·완료 화면 분기
                switch scanService.phase {
                case .checklist:
                    Color.black.opacity(0.35).ignoresSafeArea()
                    ScrollView {
                        PreScanInfo { scanService.prepare() }
                            .padding(24)
                            .frame(maxWidth: .infinity)
                    }
                    .defaultScrollAnchor(.center)
                case .ready, .scanning, .paused:
                    RoomPlanScanOverlay(
                        phase: scanService.phase,
                        guidance: scanService.guidance,
                        pauseStatus: pauseStatus,
                        isTorchOn: scanService.isTorchOn,
                        torchMessage: scanService.torchMessage,
                        onStart: scanService.begin,
                        onStop: scanService.stop,
                        onPause: scanService.pause,
                        onTorch: scanService.toggleTorch
                    )
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
                            onFinish: scanService.finish,
                            onContinue: scanService.continueScanning
                        )
                    }
                case .finished:
                    ContentUnavailableView(
                        "촬영이 완료됐어요",
                        systemImage: "checkmark.circle",
                        description: Text(finishedMessage)
                    )
                    .foregroundStyle(.white)
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
        // 앱 최초 진입 및 앱 활성화 시 카메라 권한 상태 재확인
        .task {
            await refreshCameraPermission()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await refreshCameraPermission() }
            } else {
                scanService.stop()
            }
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
    
    // 일시정지 구간의 저장·병합 진행 상태 문구
    private var pauseStatus: String? {
        guard scanService.phase == .paused else { return nil }
        if scanService.isSavingPause { return "스캔 상태 저장 중…" }
        if scanService.isMergingPreview { return "촬영한 방을 병합하는 중…" }
        if case .saveFailed = scanService.issue { return "스캔 상태를 저장하지 못했습니다" }
        return "스캔 상태 저장됨"
    }
    
    // 최종 병합 결과와 저장된 구간 수의 완료 문구
    private var finishedMessage: String {
        if scanService.isMergingStructure { return "저장된 스캔 구간을 병합하는 중입니다" }
        if scanService.mergedStructureURL != nil { return "병합된 도면을 저장했습니다" }
        if scanService.mergeError != nil { return "구간은 저장했지만 병합하지 못했습니다" }
        return "저장된 스캔 구간 \(scanService.savedSegments.count)개"
    }
    
}

//
//  RoomPlanTrackingService.swift
//  All4You
//
//  Created by 채유성 on 11/4/26.
//

// RoomPlan과 공유하는 ARSession, 월드맵 체크포인트, 구간 촬영 시간, relocalization 흐름을 관리하는 로직
import ARKit
import Foundation
import OSLog
import UIKit


@MainActor final class RoomPlanTrackingService: NSObject, ARSessionDelegate {
    private(set) var arSession = ARSession()
    var onScanLimitReached: (() -> Void)?
    var onRelocalized: (() -> Void)?
    var onRelocalizationTimeout: (() -> Void)?
    var onSessionFailure: ((Error) -> Void)?
    var onFrameStalled: (() -> Void)?
    
    private let worldMapStore: RoomPlanWorldMapService
    // 1회 스캔 한도 5분으로 설정
    // TODO: 추후 거리 제한하는 변수도 필요 - 20m * 20m 로 맞춰야할듯. 직선 거리 길어지면 방향 틀 것을 제안하는 등 방법 필요.
    private let scanLimitSeconds: TimeInterval = 5 * 60
    private var didNotifyScanLimit = false
    private var elapsedScanSeconds: TimeInterval = 0
    private var latestWorldMap: ARWorldMap?
    private var monitor: Task<Void, Never>?
    private var monitorGeneration = UUID()
    private var restartPending = false
    private var isRelocalizing = false
    private var relocalizedFrameCount = 0
    private var frameWatchdog: Task<Void, Never>?
    private var lastFrameTimestamp: TimeInterval?
    private var lastFrameAdvanceAt = Date()
    private var didReportFrameStall = false
    private let logger = Logger(subsystem: "All4You", category: "RoomPlanTracking")
    
    init(scanID: UUID) {
        worldMapStore = RoomPlanWorldMapService(scanID: scanID)
        super.init()
    }
    
    // RoomCaptureView와 같은 ARSession의 추적 시작 또는 월드맵 복원
    func attach() {
        arSession.delegate = self
        if restartPending {
            restartPending = false
            let configuration = ARWorldTrackingConfiguration()
            configuration.initialWorldMap = latestWorldMap ?? (try? worldMapStore.load())
            arSession.run(configuration, options: [.resetTracking, .removeExistingAnchors])
            // 이전 좌표계 복원 뒤 정상 추적 프레임이 연속 도착할 때까지 relocalization 대기
            let session = arSession
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(30))
                guard let self, self.isRelocalizing, self.arSession === session else { return }
                self.isRelocalizing = false
                self.onRelocalizationTimeout?()
            }
        } else {
            arSession.run(ARWorldTrackingConfiguration())
        }
        startFrameWatchdog()
    }
    
    // 실제 카메라 프레임이 진행되는 동안의 구간별 촬영 시간 감시 시작
    func startMonitoring() {
        stopMonitoring()
        didNotifyScanLimit = false
        elapsedScanSeconds = 0
        startFrameWatchdog()
        let generation = monitorGeneration
        monitor = Task { [weak self] in
            var previousTick = ProcessInfo.processInfo.systemUptime
            var previousFrameTimestamp = self?.arSession.currentFrame?.timestamp
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self, self.monitorGeneration == generation else { break }
                let now = ProcessInfo.processInfo.systemUptime
                let elapsed = now - previousTick
                previousTick = now
                let frameTimestamp = self.arSession.currentFrame?.timestamp
                defer { previousFrameTimestamp = frameTimestamp }
                guard UIApplication.shared.applicationState == .active,
                      let frameTimestamp,
                      frameTimestamp > (previousFrameTimestamp ?? -.infinity),
                      elapsed <= 3 else { continue }
                
                // 백그라운드 복귀 후의 큰 시간 간격과 멈춘 카메라 프레임은 촬영 시간에서 제외
                self.elapsedScanSeconds += elapsed
                if self.elapsedScanSeconds >= self.scanLimitSeconds, !self.didNotifyScanLimit {
                    self.didNotifyScanLimit = true
                    self.checkpointWorldMap()
                    self.onScanLimitReached?()
                }
            }
        }
    }
    
    // 종료된 구간의 시간 감시 작업 무효화
    func stopMonitoring() {
        monitor?.cancel()
        monitor = nil
        monitorGeneration = UUID()
    }
    
    // 현재 좌표계를 새 AR 세션 복원용 월드맵으로 저장
    func checkpointWorldMap() {
        arSession.getCurrentWorldMap { [weak self] map, _ in
            guard let map else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.latestWorldMap = map
                let store = self.worldMapStore
                Task.detached(priority: .utility) {
                    try? await store.save(map)
                }
            }
        }
    }
    
    // 스캔 구간 한계 이후 이전 월드맵을 복원할 새 ARSession 준비
    func prepareRestart() -> Bool {
        guard latestWorldMap != nil || (try? worldMapStore.load()) != nil else { return false }
        stopMonitoring()
        arSession.delegate = nil
        arSession.pause()
        arSession = ARSession()
        restartPending = true
        isRelocalizing = true
        relocalizedFrameCount = 0
        return true
    }
    
    // 결과가 없는 첫 촬영은 좌표계를 보존할 필요가 없으므로 실패한 ARSession을 폐기
    func resetEmptyScan() {
        stopMonitoring()
        frameWatchdog?.cancel()
        frameWatchdog = nil
        arSession.delegate = nil
        arSession.pause()
        arSession = ARSession()
        latestWorldMap = nil
        restartPending = false
        isRelocalizing = false
        relocalizedFrameCount = 0
    }
    
    // 화면 이탈 또는 최종 스캔 완료시 AR 추적 중단
    func stop() {
        stopMonitoring()
        frameWatchdog?.cancel()
        frameWatchdog = nil
        isRelocalizing = false
        arSession.delegate = nil
        arSession.pause()
    }
    
    // ARSession 오류 콜백 없이 카메라의 동일 프레임만 반복되는 상태 감지
    private func startFrameWatchdog() {
        frameWatchdog?.cancel()
        lastFrameTimestamp = arSession.currentFrame?.timestamp
        lastFrameAdvanceAt = Date()
        didReportFrameStall = false
        let session = arSession
        frameWatchdog = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled, let self, self.arSession === session else { break }
                guard UIApplication.shared.applicationState == .active else {
                    self.lastFrameAdvanceAt = Date()
                    continue
                }
                if let timestamp = session.currentFrame?.timestamp,
                   self.lastFrameTimestamp.map({ timestamp > $0 }) ?? true {
                    self.lastFrameTimestamp = timestamp
                    self.lastFrameAdvanceAt = Date()
                    self.didReportFrameStall = false
                } else if !self.didReportFrameStall,
                          Date().timeIntervalSince(self.lastFrameAdvanceAt) > 10 {
                    self.didReportFrameStall = true
                    self.logger.error("ARSession 카메라 프레임 갱신 중단")
                    self.onFrameStalled?()
                }
            }
        }
    }
    
    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard case .normal = frame.camera.trackingState else { return }
        Task { @MainActor [weak self] in
            guard let self, self.isRelocalizing, self.arSession === session else { return }
            self.relocalizedFrameCount += 1
            guard self.relocalizedFrameCount >= 5 else { return }
            self.isRelocalizing = false
            self.onRelocalized?()
        }
    }
    
    nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            guard let self, self.arSession === session else { return }
            self.logger.error("ARSession 실패: \(error.localizedDescription, privacy: .public)")
            self.onSessionFailure?(error)
        }
    }
}

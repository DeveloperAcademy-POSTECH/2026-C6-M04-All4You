//
//  RoomPlanScanService.swift
//  All4You
//
//  Created by 채유성 on 11/3/26.
//

// RoomCaptureSession 이벤트를 받아 스캔 단계, 구간 저장·재개, 미리보기 병합을 조율하고 화면 상태를 제공하는 로직
import ARKit
import Combine
import Foundation
import OSLog
import RoomPlan

@MainActor final class RoomPlanScanService: NSObject, ObservableObject, RoomCaptureSessionDelegate {
    
    // 구간 종료 요청의 목적과 콜백 처리 중복 방지를 함께 표현하는 종료 상태
    private enum CaptureEnd: Equatable {
        case pause
        case stop
        case processingPause
        case processingStop
        
        var isPausing: Bool { self == .pause || self == .processingPause }
        var isProcessing: Bool { self == .processingPause || self == .processingStop }
    }
    
    private enum PendingAction: Equatable {
        case none
        case resume
        case finish
    }
    
    // 화면에 전달되는 촬영 단계, 안내, 미리보기 및 저장 상태
    @Published private(set) var phase: RoomPlanScanPhase = .checklist
    @Published private(set) var issue: RoomPlanScanIssue?
    @Published private(set) var isScanLimitReached = false
    @Published private(set) var guidance = RoomPlanGuidanceService.beforeStart
    private var currentRoom: CapturedRoom?
    private var pausedRoom: CapturedRoom?
    private var completedRooms: [CapturedRoom] = []
    @Published private(set) var isSavingPause = false
    @Published private(set) var renderRevision = 0
    @Published private(set) var isTorchOn = false
    @Published private(set) var torchMessage: String?
    @Published private(set) var savedSegments: [URL] = []
    @Published private(set) var finalModelURL: URL?
    @Published private(set) var isMergingStructure = false
    @Published private(set) var mergedPreview: CapturedStructure?
    @Published private(set) var isMergingPreview = false
    @Published private(set) var isRelocalizing = false
    @Published private(set) var mergeError: String?
    @Published private(set) var segmentID = UUID()
    var arSession: ARSession { tracking.arSession }
    var onAutomaticStop: (() -> Void)?
    
    // 미리보기에 전달할 저장 완료 공간 결과
    var finishedRooms: [CapturedRoom] { completedRooms }
    
    // 동일 스캔 ID로 묶인 구간 저장소와 월드맵 저장소
    private let store = RoomPlanSegmentService()
    private lazy var tracking: RoomPlanTrackingService = {
        let tracking = RoomPlanTrackingService(scanID: store.scanID)
        tracking.onScanLimitReached = { [weak self] in
            guard let self, self.phase == .scanning else { return }
            self.isScanLimitReached = true
            self.needsRelocalization = true
            self.issue = .scanTimeLimitReached
            self.tracking.stopMonitoring()
            // 한계 도달 즉시 촬영을 종료하고, 저장 진행 안내를 표시
            self.onAutomaticStop?()
            self.stop()
        }
        tracking.onRelocalized = { [weak self] in
            guard let self else { return }
            let startedAt = self.relocalizationStartedAt
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.waitForMinimumProgressDuration(since: startedAt)
                guard self.isRelocalizing else { return }
                self.relocalizationStartedAt = nil
                self.isRelocalizing = false
                self.needsRelocalization = false
                self.begin()
            }
        }
        tracking.onRelocalizationTimeout = { [weak self] in
            guard let self else { return }
            self.relocalizationStartedAt = nil
            self.isRelocalizing = false
            self.issue = .captureFailed("이전 스캔 위치를 찾지 못했습니다. 마지막으로 촬영한 공간을 다시 비춰주세요")
        }
        tracking.onSessionFailure = { [weak self] error in
            guard let self else { return }
            // 아직 스캔 결과가 없다면 현재 카메라 세션을 버리고 시작 화면으로 복구
            if self.completedRooms.isEmpty,
               self.phase == .scanning,
               !RoomPlanSegmentService.hasScannedContent(self.currentRoom) {
                self.logger.error("빈 촬영 중 ARSession 실패: \(error.localizedDescription, privacy: .public)")
                self.resetEmptyScan()
            } else if self.phase == .ready {
                // 준비 중 오류는 자동 재시작을 반복하지 않고 다음 시작 입력에서 복구
                // TODO: guidance 문구 합의 필요
                self.cameraNeedsReset = true
                self.guidance = "카메라 연결이 중단됐어요. 스캔 버튼을 눌러 다시 시작해 주세요"
            }
        }
        tracking.onFrameStalled = { [weak self] in
            guard let self, self.completedRooms.isEmpty else { return }
            if self.phase == .scanning,
               !RoomPlanSegmentService.hasScannedContent(self.currentRoom) {
                self.resetEmptyScan()
            } else if self.phase == .ready {
                self.cameraNeedsReset = true
                self.guidance = "카메라 화면이 멈췄어요. 스캔 버튼을 눌러 다시 시작해 주세요"
            }
        }
        return tracking
    }()
    private let logger = Logger(subsystem: "All4You", category: "RoomPlan")
    private let torch = RoomPlanTorchService()
    
    // 세션 재개, 저장 중 입력, 재현지화를 조율하는 내부 상태
    private var captureSession: RoomCaptureSession?
    // 새 ARSession이 이전 구간의 좌표계에 맞춰질 때까지 촬영 시작 차단
    private var needsRelocalization = false
    private var ending: CaptureEnd?
    private var pendingAction: PendingAction = .none
    private var pauseGeneration = UUID()
    private var pausedSegmentSaved = false
    private var unsavedPauseData: CapturedRoomData?
    private var previewMergeID = UUID()
    private var restartAfterEmptyScan = false
    private var cameraNeedsReset = false
    private var isDetached = false
    private let minimumProgressDuration: TimeInterval = 0.5
    private var relocalizationStartedAt: TimeInterval?
    
    // 완료 구간과 일시정지 순간의 방을 중복 없이 결합한 미리보기 입력
    var previewRooms: [CapturedRoom] {
        var rooms = completedRooms
        if phase == .paused {
            if let pausedRoom {
                // 저장 완료 후에도 일시정지 순간의 형상 유지 및 중복 방 제거
                if pausedSegmentSaved, !rooms.isEmpty { rooms.removeLast() }
                rooms.append(pausedRoom)
            }
        } else if let currentRoom {
            rooms.append(currentRoom)
        }
        return rooms
    }
    
    // 촬영 단계에 따른 저장 공간 윤곽선 입력의 선택
    var outlineRooms: [CapturedRoom] {
        phase == .paused ? previewRooms : completedRooms
    }
    
    // RoomCaptureView의 세션 연결과 공유 ARSession의 카메라 미리보기 시작
    func attach(_ session: RoomCaptureSession) {
        // 새 구간에서 월드맵 재현지화 또는 기존 세션의 추적 시작
        guard session.arSession === arSession else { return }
        isDetached = false
        captureSession = session
        session.delegate = self
        tracking.attach()
        if isRelocalizing {
            guidance = "이전 스캔 위치를 비춰 위치를 찾는 중입니다"
        }
        if restartAfterEmptyScan {
            restartAfterEmptyScan = false
            // 새 RoomCaptureView가 화면에 연결된 다음 촬영 시작
            Task { @MainActor [weak self] in
                await Task.yield()
                guard let self, self.captureSession === session else { return }
                self.begin()
            }
        }
    }
    
    // 저장·병합 종료 확인 후 새 RoomPlan 촬영 구간 시작
    func begin() {
        if cameraNeedsReset, phase == .ready, completedRooms.isEmpty {
            restartAfterEmptyScan = true
            resetEmptyScan()
            return
        }
        guard let captureSession, !isRelocalizing, !needsRelocalization,
              phase == .ready || phase == .paused || phase == .segmentSaved else { return }
        // 저장 또는 중간 병합 중 재개 입력의 지연 실행 예약
        if ending?.isPausing == true {
            pendingAction = .resume
            return
        }
        if isMergingPreview {
            pendingAction = .resume
            return
        }
        if phase == .paused, unsavedPauseData != nil {
            retryPauseSave(finishAfterSave: false)
            return
        }
        issue = nil
        isScanLimitReached = false
        currentRoom = nil
        pausedRoom = nil
        pausedSegmentSaved = false
        renderRevision += 1
        ending = nil
        pendingAction = .none
        phase = .scanning
        var configuration = RoomCaptureSession.Configuration()
        configuration.isCoachingEnabled = true
        captureSession.run(configuration: configuration)
        tracking.startMonitoring()
    }
    
    // 촬영 전 확인 사항에서 촬영 준비 단계로의 전환
    func prepare() {
        guard phase == .checklist else { return }
        phase = .ready
    }
    
    // 현재 구간 종료, ARSession 유지, 마지막 방 형상의 즉시 고정
    func pause() {
        guard phase == .scanning, ending == nil, let captureSession else { return }
        // 비동기 저장 완료 전 마지막 실시간 방의 미리보기 고정
        pausedRoom = currentRoom
        pausedSegmentSaved = false
        pauseGeneration = UUID()
        isSavingPause = true
        turnTorchOff()
        ending = .pause
        pendingAction = .none
        // 실시간 형상이 없으면 재개 버튼 대신 최초 스캔 버튼을 즉시 표시
        let hasContent = RoomPlanSegmentService.hasScannedContent(currentRoom)
        phase = hasContent ? .paused : .ready
        if !hasContent { guidance = RoomPlanGuidanceService.beforeStart }
        tracking.stopMonitoring()
        tracking.checkpointWorldMap()
        captureSession.stop(pauseARSession: false)
    }
    
    // 후면 카메라 손전등 상태 전환 및 오류 안내 갱신
    func toggleTorch() {
        do {
            try torch.setEnabled(!isTorchOn)
            isTorchOn.toggle()
            torchMessage = nil
        } catch {
            torchMessage = error.localizedDescription
        }
    }
    
    private func turnTorchOff() {
        if isTorchOn { try? torch.setEnabled(false) }
        isTorchOn = false
        torchMessage = nil
    }
    
    // 현재 구간 종료와 저장 완료 후 다음 단계 전환의 예약
    func stop() {
        if phase == .paused {
            if unsavedPauseData != nil, ending?.isPausing != true {
                retryPauseSave(finishAfterSave: true)
                return
            }
            if ending?.isPausing == true {
                pendingAction = .finish
            } else {
                completeStoppedCapture()
            }
            return
        }
        guard phase == .scanning, ending == nil, let captureSession else { return }
        if isScanLimitReached {
            needsRelocalization = true
            issue = .scanTimeLimitReached
        }
        turnTorchOff()
        ending = .stop
        // 자동 종료일 때만 즉시 저장 화면으로 전환; 일반 종료는 결과 콜백을 기다림
        tracking.stopMonitoring()
        // 권장 시간 도달 시 월드맵은 시간 감시기에서 이미 저장함; 일반 종료에는 불필요
        if isScanLimitReached { phase = .saving }
        captureSession.stop(pauseARSession: false)
    }
    
    // 촬영 완료 후 한 구간은 단독 결과로, 여러 구간은 병합 결과로 내보내기
    func finish() {
        guard phase == .segmentSaved else { return }
        // 중간 구조 생성이 끝나기 전 최종 내보내기를 동시에 시작하지 않음
        if isMergingPreview {
            pendingAction = .finish
            return
        }
        pendingAction = .none
        turnTorchOff()
        phase = .finished
        tracking.stop()
        guard !completedRooms.isEmpty else {
            mergeError = "저장된 공간 결과가 없어 최종 도면을 만들 수 없습니다"
            return
        }
        isMergingStructure = true
        mergeError = nil
        let rooms = completedRooms
        let structure = mergedPreview
        let store = store
        Task { @MainActor [weak self] in
            do {
                let url = try await Task.detached(priority: .utility) {
                    try await store.saveFinalModel(from: rooms, structure: structure)
                }.value
                self?.finalModelURL = url
                self?.isMergingStructure = false
            } catch {
                self?.logger.error("스캔 구간 병합 실패: \(error.localizedDescription, privacy: .public)")
                self?.mergeError = error.localizedDescription
                self?.isMergingStructure = false
            }
        }
    }
    
    // 일반 구간의 연속 촬영 또는 권장 시간·RoomPlan 한계 도달 후 월드맵 relocalization
    func continueScanning() {
        guard phase == .segmentSaved else { return }
        if issue == .scanTimeLimitReached || issue == .sceneLimitReached {
            needsRelocalization = true
        }
        // 타임아웃으로 issue가 바뀌어도 위치를 찾기 전에는 새 구간을 시작하지 않음
        if needsRelocalization {
            guard tracking.prepareRestart() else {
                issue = .captureFailed("이전 위치 정보가 없어 연속 스캔을 시작할 수 없습니다")
                return
            }
            isRelocalizing = true
            relocalizationStartedAt = ProcessInfo.processInfo.systemUptime
            captureSession?.delegate = nil
            captureSession = nil
            currentRoom = nil
            pausedRoom = nil
            segmentID = UUID()
        } else {
            begin()
        }
    }
    
    // 화면 이탈 시 작업 취소와 카메라·손전등 자원 해제
    func detach() {
        guard !isDetached else { return }
        isDetached = true
        turnTorchOff()
        let session = captureSession
        captureSession = nil
        session?.delegate = nil
        if phase == .scanning { session?.stop() }
        tracking.stop()
    }
    
    // 실시간 CapturedRoom 갱신과 일시정지용 마지막 스캔 도면 형상 보관
    nonisolated func captureSession(_ session: RoomCaptureSession, didUpdate room: CapturedRoom) {
        Task { @MainActor [weak self] in
            guard let self, self.captureSession === session else { return }
            if self.phase == .paused && self.ending?.isPausing == true {
                self.pausedRoom = room
                self.renderRevision += 1
                return
            }
            guard self.phase == .scanning else { return }
            // RoomCaptureView의 실시간 모형과는 별도로 일시정지·저장 대체용 마지막 결과 보관
            self.currentRoom = room
        }
    }
    
    // 구간 종료 데이터의 비동기 저장, 완료 방 누적, 미리보기 병합
    nonisolated func captureSession(_ session: RoomCaptureSession, didEndWith data: CapturedRoomData, error: Error?) {
        Task { @MainActor [weak self] in
            guard let self, self.captureSession === session,
                  self.phase == .saving || self.phase == .paused || self.phase == .scanning || self.phase == .ready,
                  self.ending?.isProcessing != true else { return }
            if self.ending == nil {
                self.logger.warning("사용자 종료 요청 없이 RoomPlan 촬영 종료: \(error?.localizedDescription ?? "오류 정보 없음", privacy: .public)")
            }
            let wasPaused = self.ending?.isPausing == true
            // RoomPlan 원본 콜백에서 구간 저장, 방 누적, 미리보기 병합으로 이어지는 데이터 흐름
            self.ending = wasPaused ? .processingPause : .processingStop
            self.tracking.stopMonitoring()
            if let captureError = error as? RoomCaptureSession.CaptureError {
                if captureError == .exceedSceneSizeLimit {
                    self.isScanLimitReached = true
                    self.needsRelocalization = true
                    self.issue = .sceneLimitReached
                    // RoomPlan이 먼저 세션을 끝낸 경우에만 다음 구간용 위치 저장 시도
                    self.tracking.checkpointWorldMap()
                    self.onAutomaticStop?()
                } else {
                    self.issue = .captureFailed(captureError.localizedDescription)
                }
            } else if let error {
                self.issue = .captureFailed(error.localizedDescription)
            }
            let pauseGeneration = self.pauseGeneration
            let fallbackRoom = wasPaused ? self.pausedRoom : self.currentRoom
            if wasPaused { self.unsavedPauseData = data }
            if !wasPaused { self.phase = .saving }
            let savingStartedAt = ProcessInfo.processInfo.systemUptime
            // 카메라 화면 지연 방지를 위한 CapturedRoomData 백그라운드 인코딩
            let result = await self.saveSegment(data, fallbackRoom: fallbackRoom)
            guard self.captureSession === session else { return }
            if !wasPaused {
                // 저장 결과와 관계없이 진행 화면의 최소 표시 시간 확보
                await self.waitForMinimumProgressDuration(since: savingStartedAt)
                guard self.captureSession === session else { return }
            }
            switch result {
            case .success(let saved):
                self.applySavedSegment(saved, wasPaused: wasPaused, pauseGeneration: pauseGeneration)
            case .failure(let error as RoomPlanSegmentService.SaveError) where error == .emptyScan:
                // 빈 구간은 저장하지 않고, 기존 결과 유무와 종료 목적에 따라 복구 또는 최종화
                self.logger.notice("인식된 공간 없이 촬영 종료; 빈 세션 복구")
                let startRequested = self.pendingAction == .resume
                self.unsavedPauseData = nil
                if self.completedRooms.isEmpty {
                    self.restartAfterEmptyScan = startRequested
                    self.resetEmptyScan()
                } else if !wasPaused {
                    // 추가 구간이 비어 있어도 이전에 저장한 구간으로 최종 도면 제공
                    self.ending = nil
                    self.finishWithSavedRooms()
                } else {
                    // 빈 일시정지 구간은 종료된 캡처 세션만 교체하고 AR 좌표계는 유지
                    self.captureSession?.delegate = nil
                    self.captureSession = nil
                    self.pausedRoom = nil
                    self.currentRoom = nil
                    self.isSavingPause = false
                    self.ending = nil
                    self.pendingAction = .none
                    self.issue = nil
                    self.guidance = RoomPlanGuidanceService.beforeStart
                    self.restartAfterEmptyScan = startRequested
                    self.phase = .ready
                    self.segmentID = UUID()
                }
                return
            case .failure(let error):
                self.logger.error("스캔 구간 저장 실패: \(error.localizedDescription, privacy: .public)")
                self.issue = .saveFailed(error.localizedDescription)
                if wasPaused {
                    self.isSavingPause = false
                    self.ending = nil
                    self.pendingAction = .none
                    self.phase = .paused
                    return
                }
            }
            self.isSavingPause = false
            self.ending = nil
            if case .saveFailed = self.issue, !self.needsRelocalization, !wasPaused {
                if !self.completedRooms.isEmpty {
                    // 새 구간 저장에 실패해도 앞서 저장한 결과는 미리보기로 전달
                    self.finishWithSavedRooms()
                    return
                }
                self.guidance = "스캔 결과를 저장하지 못했어요. 다시 촬영해 주세요"
                self.resetEmptyScan()
                return
            }
            if wasPaused {
                if self.pendingAction == .finish {
                    self.completeStoppedCapture()
                } else if self.pendingAction == .resume {
                    self.begin()
                } else {
                    self.phase = .paused
                }
            } else {
                self.completeStoppedCapture()
            }
        }
    }
    
    // 빈 촬영 이후 기존 세션의 정지 상태를 재사용하지 않도록 카메라와 AR 추적을 새로 연결
    private func resetEmptyScan() {
        captureSession?.delegate = nil
        captureSession?.stop(pauseARSession: false)
        captureSession = nil
        tracking.resetEmptyScan()
        currentRoom = nil
        pausedRoom = nil
        unsavedPauseData = nil
        isSavingPause = false
        ending = nil
        pendingAction = .none
        issue = nil
        isScanLimitReached = false
        needsRelocalization = false
        isRelocalizing = false
        relocalizationStartedAt = nil
        cameraNeedsReset = false
        guidance = RoomPlanGuidanceService.beforeStart
        phase = .ready
        segmentID = UUID()
    }
    
    // 저장 실패 구간의 원본 데이터 보존과 동일 인덱스 재저장
    private func retryPauseSave(finishAfterSave: Bool) {
        if isSavingPause {
            pendingAction = finishAfterSave ? .finish : .resume
            return
        }
        guard let data = unsavedPauseData else { return }
        pendingAction = finishAfterSave ? .finish : .resume
        isSavingPause = true
        let fallbackRoom = pausedRoom
        let pauseGeneration = pauseGeneration
        Task { @MainActor [weak self] in
            guard let self else { return }
            let result = await self.saveSegment(data, fallbackRoom: fallbackRoom)
            self.isSavingPause = false
            switch result {
            case .success(let saved):
                self.applySavedSegment(saved, wasPaused: true, pauseGeneration: pauseGeneration)
                self.issue = nil
                if self.pendingAction == .finish {
                    self.completeStoppedCapture()
                } else {
                    self.begin()
                }
            case .failure(let error):
                self.logger.error("일시정지 구간 재저장 실패: \(error.localizedDescription, privacy: .public)")
                self.issue = .saveFailed(error.localizedDescription)
            }
        }
    }
    
    // 정상 종료는 최종 미리보기로 이동, 스캔 한계에 도달했을 때 중단하는 경우에는 SegmentDialog뷰 띄움
    private func finishWithSavedRooms() {
        needsRelocalization = false
        isScanLimitReached = false
        issue = nil
        currentRoom = nil
        pausedRoom = nil
        completeStoppedCapture()
    }
    
    private func completeStoppedCapture() {
        pendingAction = .none
        guard !completedRooms.isEmpty else {
            needsRelocalization = false
            if case .saveFailed = issue {
                guidance = "스캔 결과를 저장하지 못했어요. 다시 촬영해 주세요"
            } else {
                issue = nil
                guidance = RoomPlanGuidanceService.beforeStart
            }
            phase = .ready
            return
        }
        phase = .segmentSaved
        if !needsRelocalization { finish() }
    }
    
    // 저장된 방 배열의 중간 CapturedStructure 병합과 미리보기 교체
    private func mergePreview() {
        guard completedRooms.count >= 2 else { return }
        let id = UUID()
        previewMergeID = id
        isMergingPreview = true
        let mergingStartedAt = ProcessInfo.processInfo.systemUptime
        let rooms = completedRooms
        let store = store
        Task { @MainActor [weak self] in
            let result = await Task.detached(priority: .utility) {
                try? await store.buildStructure(from: rooms)
            }.value
            guard let self, self.previewMergeID == id else { return }
            await self.waitForMinimumProgressDuration(since: mergingStartedAt)
            guard self.previewMergeID == id else { return }
            self.mergedPreview = result
            self.isMergingPreview = false
            self.renderRevision += 1
            if result == nil {
                self.logger.error("중간 스캔 병합 실패; 개별 방 결과를 계속 표시합니다")
            }
            if self.pendingAction == .finish, self.phase == .segmentSaved {
                self.finish()
                return
            }
            if self.pendingAction == .resume,
               self.phase == .paused || self.phase == .segmentSaved || self.phase == .ready {
                self.begin()
            }
        }
    }
    
    // 구간 번호에 맞춘 비동기 원본 저장과 후처리 결과 반환
    private func saveSegment(
        _ data: CapturedRoomData,
        fallbackRoom: CapturedRoom?
    ) async -> Result<SavedRoomPlanSegment, Error> {
        let store = store
        let index = savedSegments.count + 1
        return await Task.detached(priority: .utility) {
            do {
                return Result.success(try await store.save(data, index: index, fallbackRoom: fallbackRoom))
            } catch {
                return Result.failure(error)
            }
        }.value
    }
    
    // 작업이 빨리 끝나도 사용자가 진행 상태를 인지할 수 있도록 최소 노출 시간 보장
    private func waitForMinimumProgressDuration(since startedAt: TimeInterval?) async {
        guard let startedAt else { return }
        let elapsed = ProcessInfo.processInfo.systemUptime - startedAt
        let remaining = max(0, minimumProgressDuration - elapsed)
        if remaining > 0 { try? await Task.sleep(for: .seconds(remaining)) }
    }
    
    // 저장된 구간의 URL·방 누적과 일시정지 순간 나오는 스캔 결과 형상 중복 제거 (겹치는 현상 방지)
    private func applySavedSegment(
        _ saved: SavedRoomPlanSegment,
        wasPaused: Bool,
        pauseGeneration: UUID
    ) {
        savedSegments.append(saved.url)
        if wasPaused { unsavedPauseData = nil }
        guard let room = saved.room else { return }
        completedRooms.append(room)
        mergePreview()
        if wasPaused, phase == .paused,
           self.pauseGeneration == pauseGeneration,
           pausedRoom != nil {
            pausedSegmentSaved = true
        } else {
            renderRevision += 1
        }
    }
    
}

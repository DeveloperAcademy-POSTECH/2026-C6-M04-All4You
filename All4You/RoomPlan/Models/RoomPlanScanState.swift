//
//  RoomPlanScanState.swift
//  All4You
//
//  Created by 채유성 on 11/3/26.
//

import Foundation

// 확인 화면, 준비, 스캔, 일시정지, 저장, 구간 완료, 전체 완료를 구분하는 화면·세션 state
enum RoomPlanScanPhase: Equatable {
    case checklist
    case ready
    case scanning
    case paused
    case saving
    case segmentSaved
    case finished
}

// 권장 촬영 시간·RoomPlan 한계와 촬영·파일 저장 오류를 화면에 전달하기 위한 state
enum RoomPlanScanIssue: Equatable {
    case scanTimeLimitReached
    case sceneLimitReached
    case captureFailed(String)
    case saveFailed(String)
}


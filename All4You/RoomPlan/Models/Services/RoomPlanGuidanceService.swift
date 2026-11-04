//
//  RoomPlanGuidanceService.swift
//  All4You
//
//  Created by 채유성 on 11/3/26.
//

// RoomCaptureSession 안내 이벤트 문구 설정하는 로직
import RoomPlan

enum RoomPlanGuidanceService {
    
    // 촬영 전 / 중  안내 문구
    static let beforeStart = "촬영 버튼을 누르고 아이패드를 움직여 스캔을 시작해보세요"
    static let defaultScanning = "벽 모서리를 카메라로 비춰주세요"
    static let lightScanning = "밝은 빛으로 공간을 비춰주세요"

    // 촬영 중 기본 안내 / 밝기 안내 번갈아 보여줌
    static func alternating(at index: Int) -> String {
        index.isMultiple(of: 2) ? defaultScanning : lightScanning
    }

    // RoomCaptureSession.Instruction별 한국어 문구 매핑
    static func message(for instruction: RoomCaptureSession.Instruction) -> String {
        switch instruction {
        case .moveCloseToWall:
            "벽과 모서리에 조금 더 가까이 다가가 주세요"
        case .moveAwayFromWall:
            "벽에서 조금 떨어져 공간 전체를 비춰주세요"
        case .slowDown:
            "아이패드를 천천히 움직여주세요"
        case .turnOnLight:
            lightScanning
        case .lowTexture:
            "특징이 보이는 벽과 모서리를 비춰주세요"
        case .normal:
            defaultScanning
        @unknown default:
            defaultScanning
        }
    }
}

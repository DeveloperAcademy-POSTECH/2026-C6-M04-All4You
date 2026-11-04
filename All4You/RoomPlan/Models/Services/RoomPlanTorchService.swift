//
//  RoomPlanTorchService.swift
//  All4You
//
//  Created by 채유성 on 11/3/26.
//

// 손전등 사용 가능 여부를 확인하고 켜짐·꺼짐을 제어하는 로직
import AVFoundation

@MainActor final class RoomPlanTorchService {
    private var device: AVCaptureDevice? {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    }
    
    // 손전등 사용 가능 여부 확인 및 카메라 설정 잠금 후 손전등 상태 변경 (크래시 방지)
    func setEnabled(_ enabled: Bool) throws {
        guard let device, device.hasTorch, device.isTorchAvailable else {
            throw TorchError.unavailable
        }
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        if enabled {
            try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
        } else {
            device.torchMode = .off
        }
    }
    
    // 손전등 미지원 또는 사용 불가 상태의 사용자 안내
    enum TorchError: LocalizedError {
        case unavailable
        
        var errorDescription: String? {
            "이 기기에서는 손전등을 켤 수 없어요. 주변 조명을 밝혀 주세요."
        }
    }
}

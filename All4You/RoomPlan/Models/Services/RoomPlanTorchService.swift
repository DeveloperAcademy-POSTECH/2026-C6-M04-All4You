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
    
    // 실제 하드웨어 상태를 기준으로 UI를 동기화한다.
    var isEnabled: Bool { device?.isTorchActive ?? false }

    // 손전등 사용 가능 여부 확인 및 카메라 설정 잠금 후 손전등 상태 변경 (크래시 방지)
    func setEnabled(_ enabled: Bool) throws {
        guard let device, device.hasTorch else {
            throw TorchError.unavailable
        }
        guard device.isTorchAvailable else {
            throw TorchError.temporarilyUnavailable
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
        case temporarilyUnavailable

        var errorDescription: String? {
            switch self {
            case .unavailable:
                return "이 기기는 손전등을 지원하지 않아요."
            case .temporarilyUnavailable:
                return "카메라 사용 중 손전등을 켤 수 없어요. 잠시 후 다시 시도해 주세요."
            }
        }
    }
}

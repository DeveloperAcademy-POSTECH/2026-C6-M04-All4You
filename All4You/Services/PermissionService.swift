// 카메라·사진 보관함·위치 권한을 확인하고 요청하는 도우미. 화면은 결과만 받아 다음 일을 정한다
//
// 시스템 권한 알림에 보이는 설명 문구는 project.pbxproj(빌드 설정의 Info.plist 항목)에 있다.
// Info.plist에는 주석을 달 수 없어 여기에 모아 적는다
// - NSCameraUsageDescription: "공간 스캔과 도면 촬영을 위해 카메라를 사용합니다." (팀원이 넣은 문구)
// - NSPhotoLibraryUsageDescription: "사진을 가져오기 위해 사진 앱에 접근합니다" (Figma 40:9417)
// - NSLocationWhenInUseUsageDescription: "사진의 위치정보를 확인하기 위해 사용합니다" (Figma 40:9529)
// TEMP: 사진 보관함·위치 문구는 Figma 문구를 그대로 옮김 — 팀 확정 필요

import AVFoundation
import CoreLocation
import Photos
import UIKit

/// 권한 상태를 읽고, 아직 묻지 않았으면 시스템 알림으로 묻는다.
/// 기억할 상태가 없어서 인스턴스를 만들지 않는 enum의 static 함수로 둔다
enum PermissionService {
    /// 카메라를 쓸 수 있으면 true. 아직 묻지 않았으면 시스템 알림을 띄우고 답을 기다린다
    static func requestCameraPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            // 거절(denied)했거나 기기 관리로 막힌(restricted) 상태. 다시 물을 수 없고 설정 앱에서만 바꿀 수 있다
            return false
        }
    }

    /// 사진 보관함을 읽을 수 있으면 true. 아직 묻지 않았으면 시스템 알림을 띄우고 답을 기다린다.
    /// 사진을 골라서만 허용한 경우(limited)도 그 사진은 읽을 수 있으므로 허용으로 본다
    static func requestPhotoLibraryPermission() async -> Bool {
        var status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .notDetermined {
            status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }
        return status == .authorized || status == .limited
    }

    // TEMP: 위치를 거절해도 사진 촬영은 막지 않아서 답을 기다리지 않음 — 위치를 꼭 받아야 한다고 정해지면 답을 기다리도록 바꿔야 함
    /// 위치를 아직 묻지 않았으면 시스템 알림을 띄운다. 답은 기다리지 않는다.
    /// 위치는 CLLocationManager가 답을 delegate로만 알려 줘서, 기다리려면 따로 객체를 둬야 한다
    static func requestLocationPermission() {
        guard locationManager.authorizationStatus == .notDetermined else { return }
        locationManager.requestWhenInUseAuthorization()
    }

    /// 거절된 권한은 앱에서 다시 물을 수 없어서, 이 앱의 설정 화면을 연다
    static func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    /// 요청 알림이 떠 있는 동안 사라지지 않도록 하나를 계속 들고 있는다
    private static let locationManager = CLLocationManager()
}

// 카메라·사진 보관함·위치 권한을 확인하고 요청하는 도우미. 화면은 결과만 받아 다음 일을 정한다
//
// 시스템 권한 알림에 보이는 설명 문구는 project.pbxproj(빌드 설정의 Info.plist 항목)에 있다.
// Info.plist에는 주석을 달 수 없어 여기에 모아 적는다
// - NSCameraUsageDescription: "공간 스캔과 도면 촬영을 위해 카메라를 사용합니다." (팀원이 넣은 문구)
// - NSPhotoLibraryUsageDescription: "사진을 가져오기 위해 사진 앱에 접근합니다" (Figma 사진 권한 화면)
// - NSLocationWhenInUseUsageDescription: "사진의 위치정보를 확인하기 위해 사용합니다" (Figma 위치 권한 화면)
// TEMP: 사진 보관함·위치 문구는 Figma 문구를 그대로 옮김 — 팀 확정 필요

import AVFoundation
import CoreLocation
import Photos
import UIKit

/// 권한 상태를 읽고, 아직 묻지 않았으면 시스템 알림으로 묻는다.
/// 기억할 상태가 없어서 인스턴스를 만들지 않는 enum의 static 함수로 둔다
enum PermissionService {
    /// 권한을 확인·요청한 결과. 거절은 "방금 알림에서 거절"과 "전에 이미 거절"을 나눈다.
    /// 거절된 권한은 시스템 알림을 다시 띄울 수 없어서, 이미 거절된 경우에만 화면이 설정 앱으로 안내한다
    enum Result {
        case allowed
        case deniedNow
        case deniedBefore
    }

    /// 카메라 권한을 확인하고, 아직 묻지 않았으면 시스템 알림을 띄워 답을 기다린다
    static func requestCameraPermission() async -> Result {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return .allowed
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video) ? .allowed : .deniedNow
        default:
            // 거절(denied)했거나 기기 관리로 막힌(restricted) 상태. 다시 물을 수 없고 설정 앱에서만 바꿀 수 있다
            return .deniedBefore
        }
    }

    /// 사진 보관함 권한을 확인하고, 아직 묻지 않았으면 시스템 알림을 띄워 답을 기다린다.
    /// 사진을 골라서만 허용한 경우(limited)도 그 사진은 읽을 수 있으므로 허용으로 본다
    static func requestPhotoLibraryPermission() async -> Result {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .notDetermined {
            let answer = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            return isPhotoLibraryAllowed(answer) ? .allowed : .deniedNow
        }
        return isPhotoLibraryAllowed(status) ? .allowed : .deniedBefore
    }

    /// 위치 권한을 확인하고, 아직 묻지 않았으면 시스템 알림을 띄워 답을 기다린다
    static func requestLocationPermission() async -> Result {
        // 기기 전체 위치 서비스가 꺼져 있으면 요청해도 알림이 뜨지 않고 답도 오지 않는다.
        // 이 확인은 메인 스레드에서 부르면 화면이 멈출 수 있다는 경고가 있어 다른 스레드에서 한다
        let isServiceOn = await Task.detached { CLLocationManager.locationServicesEnabled() }.value
        guard isServiceOn else { return .deniedBefore }

        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return .allowed
        case .notDetermined:
            let answer = await locationAnswer.waitForAnswer(from: locationManager)
            return answer == .authorizedWhenInUse || answer == .authorizedAlways ? .allowed : .deniedNow
        default:
            return .deniedBefore
        }
    }

    /// 거절된 권한은 앱에서 다시 물을 수 없어서, 이 앱의 설정 화면을 연다
    static func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private static func isPhotoLibraryAllowed(_ status: PHAuthorizationStatus) -> Bool {
        status == .authorized || status == .limited
    }

    /// 요청 알림이 떠 있는 동안 사라지지 않도록 하나를 계속 들고 있는다
    private static let locationManager = CLLocationManager()
    private static let locationAnswer = LocationAnswer()
}

/// 위치 권한의 답은 await로 오지 않고 delegate로만 와서, 그 답을 받아 await로 돌려주는 연결 객체.
/// 화면 상태를 들고 있는 것이 아니라 애플 위치 기능과 잇기 위한 것이다 (UIKit 연결과 같은 성격)
/// CLLocationManager는 메인 스레드에서 다루도록 권장되어 메인 스레드에서만 돈다
@MainActor
private final class LocationAnswer: NSObject, CLLocationManagerDelegate {
    private var continuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    // 답을 기다리는 중인 요청. 그동안 또 불리면 새로 묻지 않고 이 요청의 답을 함께 기다린다
    private var pendingAnswer: Task<CLAuthorizationStatus, Never>?

    /// 알림을 띄우고, 사용자가 답할 때까지 기다렸다가 그 상태를 돌려준다.
    /// 기다리는 곳(continuation)은 하나뿐이라, 겹쳐 불리면 앞 요청이 영영 답을 못 받지 않도록 진행 중인 요청을 함께 쓴다
    func waitForAnswer(from manager: CLLocationManager) async -> CLAuthorizationStatus {
        if let pendingAnswer {
            return await pendingAnswer.value
        }
        let request = Task {
            await withCheckedContinuation { continuation in
                self.continuation = continuation
                manager.delegate = self
                manager.requestWhenInUseAuthorization()
            }
        }
        pendingAnswer = request
        let answer = await request.value
        pendingAnswer = nil
        return answer
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // delegate를 붙이는 순간에도 한 번 불리므로, 아직 답이 없을 때(notDetermined)는 넘긴다
        guard manager.authorizationStatus != .notDetermined else { return }
        continuation?.resume(returning: manager.authorizationStatus)
        continuation = nil
    }
}

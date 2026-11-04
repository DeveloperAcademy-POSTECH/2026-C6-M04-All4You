//
//  RoomPlanCameraSurface.swift
//  All4You
//
//  Created by 채유성 on 11/3/26.
//

// 공유 ARSession을 사용하는 RoomCaptureView의 생성, 연결, 촬영 화면 생명주기를 관리하는 파일
import ARKit
import RoomPlan
import SwiftUI

struct RoomPlanCameraSurface: UIViewRepresentable {
    let scanService: RoomPlanScanService
    
    func makeCoordinator() -> ResultPresentationDelegate {
        ResultPresentationDelegate()
    }
    
    // 서비스의 ARSession을 공유하는 RoomCaptureView 생성과 캡처 세션 연결
    func makeUIView(context: Context) -> RoomCaptureView {
        let view = RoomCaptureView(frame: .zero, arSession: scanService.arSession)
        // RoomPlan이 직접 갱신하는 실시간 축소 모형 사용
        view.isModelEnabled = true
        view.delegate = context.coordinator
        scanService.attach(view.captureSession)
        return view
    }
    
    func updateUIView(_ view: RoomCaptureView, context: Context) {
        // 현재 촬영 구간에 대한 RoomPlan 기본 모형 유지
        // 세션 연결은 makeUIView에서 한 번 수행하므로 갱신 시 재시작하지 않음
        view.isModelEnabled = true
    }
    
    // UIView 제거 시 일 연결 해제와 AR 세션 중단
    static func dismantleUIView(_ view: RoomCaptureView, coordinator: ResultPresentationDelegate) {
        view.delegate = nil
        view.captureSession.delegate = nil
        view.captureSession.stop()
        view.captureSession.arSession.pause()
    }
}

// 스캔 종료 시 RoomPlan 기본 결과 화면으로 전환되는것 차단 (원하는 화면을 커스텀해 보여주기 위해)
final class ResultPresentationDelegate: NSObject, RoomCaptureViewDelegate {
    override init() {
        super.init()
    }
    
    required init?(coder: NSCoder) {
        super.init()
    }
    
    func encode(with coder: NSCoder) {}
    
    // 스캔 일시정지시 병합된 도면을 보여주는 화면을 위해 기본 스캔 결과를 보여주는 화면 막기
    func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: Error?) -> Bool {
        false
    }
}

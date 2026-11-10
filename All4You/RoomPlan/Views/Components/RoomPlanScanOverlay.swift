//
//  RoomPlanScanOverlay.swift
//  All4You
//
//  Created by 채유성 on 11/3/26.
//

// 스캔 단계에 맞춰 안내 문구, 손전등 토글, 촬영 시작·종료·일시정지·재개 버튼을 배치하는 뷰 (카메라 위에 올라가는 overlay)
import SwiftUI

struct RoomPlanScanOverlay: View {
    let phase: RoomPlanScanPhase
    let guidance: String
    let pauseStatus: String?
    let isTorchOn: Bool
    let torchMessage: String?
    let onStart: () -> Void
    let onStop: () -> Void
    let onPause: () -> Void
    let onTorch: () -> Void
    /// 스캔 중 사진 촬영 (사진에 카메라 위치·방향이 함께 담김)
    var photoCount = 0
    var canCapturePhoto = false
    var photoMessage: String?
    var onCapturePhoto: () -> Void = {}
    
    var body: some View {
        ZStack {
            if phase == .ready {
                Color.black.opacity(0.32).ignoresSafeArea()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if phase == .ready {
                VStack(spacing: 28) {
                    RoomPlanCoachingGraphic()
                    
                    Text(guidance)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .top) {
            VStack(spacing: 8) {
                if let torchMessage {
                    Label(torchMessage, systemImage: "flashlight.on.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                }
                if let photoMessage {
                    Label(photoMessage, systemImage: "location.slash")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                }
                if let pauseStatus {
                    Text(pauseStatus)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                }
            }
            .padding(.top, 90)
            .padding(.horizontal, 24)
        }
        
        // 준비·촬영·일시정지 단계에 따른 촬영 버튼 모양 전환
        .overlay(alignment: .trailing) {
            if phase == .ready {
                Button(action: onStart) {
                    Circle()
                        .fill(.red)
                        .frame(width: 58, height: 58)
                        .frame(width: 72, height: 72)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("스캔 시작")
                .padding(.trailing, 28)
            } else if phase == .scanning || phase == .paused {
                Button(action: onStop) {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(.red)
                        .frame(width: 27, height: 27)
                        .frame(width: 72, height: 72)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("촬영 종료")
                .padding(.trailing, 28)
            }
        }
        
        // 촬영 중 일시정지 & 일시정지 상태에서 다시 스캔
        .overlay(alignment: .trailing) {
            if phase == .scanning {
                Button(action: onPause) {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 54, height: 54)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("스캔 일시정지")
                .padding(.trailing, 37)
                .offset(y: 180)
            } else if phase == .paused {
                Button(action: onStart) {
                    Circle()
                        .fill(.red)
                        .frame(width: 58, height: 58)
                        .padding(5)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                        .frame(width: 72, height: 72)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("스캔 재개")
                .padding(.trailing, 28)
                .offset(y: 180)
            }
        }
        
        // 스캔·일시정지 중 사진 촬영. 찍은 장 수를 배지로 보여 줌
        .overlay(alignment: .trailing) {
            if phase == .scanning || phase == .paused {
                Button(action: onCapturePhoto) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 54, height: 54)
                        .background(.black.opacity(0.35), in: Circle())
                        .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                        .overlay(alignment: .topTrailing) {
                            if photoCount > 0 {
                                Text(photoCount, format: .number)
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .frame(minWidth: 22, minHeight: 22)
                                    .background(.red, in: Capsule())
                                    .offset(x: 6, y: -6)
                            }
                        }
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(!canCapturePhoto)
                .opacity(canCapturePhoto ? 1 : 0.5)
                .sensoryFeedback(.impact(weight: .light), trigger: photoCount)
                .accessibilityLabel("사진 촬영")
                .accessibilityValue("\(photoCount)장")
                .padding(.trailing, 37)
                .offset(y: -100)
            }
        }
        
        // 촬영 시작 이후 손전등 버튼 보여줌
        .overlay(alignment: .trailing) {
            if phase == .scanning || phase == .paused {
                Button(action: onTorch) {
                    Image(systemName: isTorchOn ? "bolt.fill" : "bolt.slash.fill")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isTorchOn ? "손전등 끄기" : "손전등 켜기")
                .padding(.trailing, 52)
                .offset(y: -180)
            }
        }
    }
}

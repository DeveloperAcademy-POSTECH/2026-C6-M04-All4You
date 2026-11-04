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
    
    var body: some View {
        ZStack {
            if phase == .ready {
                Color.black.opacity(0.32).ignoresSafeArea()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if phase == .ready || phase == .scanning {
                Text(guidance)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 100)
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
                        .padding(5)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                        .frame(width: 72, height: 72)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("스캔 시작")
                .padding(.trailing, 24)
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

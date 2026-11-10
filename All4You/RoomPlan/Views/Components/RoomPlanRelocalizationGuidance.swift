//
//  RoomPlanRelocalizationGuidance.swift
//  All4You
//

import SwiftUI

// 이전 스캔 좌표계를 찾는 동안 카메라 화면 위에 표시하는 안내
struct RoomPlanRelocalizationGuidance: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.68)
                .ignoresSafeArea()
            
            VStack(spacing: 10) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.35)
                    .padding(.bottom, 12)
                
                Text("이전 스캔 위치를 찾고 있어요")
                    .font(AppTypography.title3Emphasized)
                
                Text("마지막으로 스캔한 곳 근처를 카메라로 비춰주세요")
                    .font(.system(size: 17))
            }
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

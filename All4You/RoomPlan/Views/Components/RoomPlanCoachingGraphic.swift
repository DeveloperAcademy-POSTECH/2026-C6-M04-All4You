//
//  RoomPlanCoachingGraphic.swift
//  All4You
//
//  Created by 채유성 on 11/3/26.
//

// 스캔 안내에 사용되는 도형들 컴포넌트
import SwiftUI


struct RoomPlanCoachingGraphic: View {
    // 공간 프레임, 특징점, 기기 모양의 안내 도형 구성
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.9), lineWidth: 2)
                .frame(width: 184, height: 168)
            
            VStack(spacing: 9) {
                ForEach(0..<4, id: \.self) { _ in
                    HStack(spacing: 11) {
                        ForEach(0..<5, id: \.self) { _ in
                            Circle()
                                .fill(.white.opacity(0.85))
                                .frame(width: 3, height: 3)
                        }
                    }
                }
            }
            .offset(x: -25, y: -28)
            
            RoundedRectangle(cornerRadius: 5)
                .fill(.white.opacity(0.75))
                .frame(width: 31, height: 54)
                .overlay {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(.white, lineWidth: 3)
                }
                .offset(x: 58, y: 1)
        }
        .frame(width: 190, height: 174)
        .accessibilityHidden(true)
    }
}


//
//  RoomPlanLimitGuidance.swift
//  All4You
//
//  Created by 채유성 on 11/7/26.
//

// 최대 스캔량 안내와 자동 저장 진행 상태를 카메라 위에 표시하는 뷰
import Foundation
import SwiftUI

struct RoomPlanLimitGuidance: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.68)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                dotGraphic
                Text("최대 스캔량에 도달했어요. 스캔 내용을 저장하고 있어요.")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
    
    // 주황색 점을 애니메이션
    private var dotGraphic: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            VStack(spacing: 30) {
                ForEach(0..<4, id: \.self) { row in
                    HStack(spacing: 30) {
                        ForEach(0..<5, id: \.self) { column in
                            let pulse = (sin(time * 4.5 - Double(row * 5 + column) * 0.38) + 1) / 2
                            Circle()
                                .fill(Color("Brand500"))
                                .frame(
                                    width: dotSize(row: row, column: column),
                                    height: dotSize(row: row, column: column)
                                )
                                .opacity(0.4 + 0.6 * pulse)
                                .scaleEffect(0.75 + 0.25 * pulse)
                                .offset(y: -3 * pulse)
                                .frame(width: 8, height: 8)
                        }
                    }
                }
            }
            .frame(height: 136)
        }
        .accessibilityHidden(true)
    }
    
    private func dotSize(row: Int, column: Int) -> CGFloat {
        row == 1 && (column == 2 || column == 3) ? 10 : 6
    }
}

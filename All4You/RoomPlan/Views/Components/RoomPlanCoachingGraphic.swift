//
//  RoomPlanCoachingGraphic.swift
//  All4You
//
//  Created by 채유성 on 11/3/26.
//

// 스캔 시작 전 안내에 띄우는 아이패드 모형
import SwiftUI

struct RoomPlanCoachingGraphic: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 11)
                .fill(.white)
                .frame(width: 64, height: 86)
            
            RoundedRectangle(cornerRadius: 7)
                .fill(Color(white: 0.84))
                .frame(width: 54, height: 76)
                .overlay {
                    RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(Color(white: 0.67), lineWidth: 2)
                }
        }
        .frame(width: 64, height: 86)
        .accessibilityHidden(true)
    }
}

//
//  FloorPlanMemoPinView.swift
//  All4You
//
//  Created by 채유성 on 11/12/26.
//

// 저장된 메모의 말풍선 핀
import SwiftUI

struct FloorPlanMemoPinView: View {
    let number: Int
    let isHighlighted: Bool
    
    var body: some View {
        ZStack {
            if isHighlighted {
                Image(systemName: "message.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.brand500)
                    .frame(width: Layout.size + 4, height: Layout.height + 4)
            }
            
            Image(systemName: "message.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.black)
                .frame(width: Layout.size, height: Layout.height)
            
            Text("\(number)")
                .font(AppTypography.subheadlineEmphasized)
                .foregroundStyle(.white)
                .offset(y: -2)
        }
        .frame(width: Layout.size + 4, height: Layout.height + 4)
    }
    
    private enum Layout {
        static let size: CGFloat = 38
        static let height: CGFloat = size * 37 / 40
    }
}

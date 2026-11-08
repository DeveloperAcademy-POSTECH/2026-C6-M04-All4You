//
//  FloorPlanMemoListComponents.swift
//  All4You
//
//  Created by 채유성 on 11/09/26.
//

import SwiftUI

struct FloorPlanMemoSectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(AppTypography.title1Emphasized)
            .foregroundStyle(.black)
            .textCase(nil)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 5)
            .accessibilityAddTraits(.isHeader)
    }
}

struct FloorPlanMemoRow: View {
    let memo: FloorPlanMemo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(memo.title)
                .font(AppTypography.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)
            
            HStack {
                Text(memo.dateText)
                
                Spacer()
                
                Text(memo.timeText)
            }
            .font(AppTypography.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 67, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

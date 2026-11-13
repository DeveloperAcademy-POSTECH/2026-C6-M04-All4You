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
    let isSelected: Bool
    let showsDivider: Bool
    let action: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                Text(memo.title)
                    .font(AppTypography.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                HStack {
                    Text(memo.dateText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    Spacer()
                    
                    Text(memo.timeText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .font(AppTypography.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            }
        }
        
        // 같은 섹션의 다음 메모가 있을 때만 텍스트 양끝에 맞춰 구분선 표시
        .overlay(alignment: .bottom) {
            if showsDivider {
                Rectangle()
                    .fill(Color(.separator).opacity(0.45))
                    .frame(height: 1)
                    .padding(.horizontal, 32)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .memoDeleteMenu(allowsSwipeDelete: true, onDelete: onDelete)
    }
}

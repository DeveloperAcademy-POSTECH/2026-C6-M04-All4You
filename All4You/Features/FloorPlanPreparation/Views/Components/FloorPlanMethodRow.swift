//
//  FloorPlanMethodRow.swift
//  All4You
//
//  Created by 채유성 on 11/1/26.
//

// 평면도 불러오는 방식 선택하는 컴포넌트
import SwiftUI

struct FloorPlanMethodRow: View {
    let sourceType: FloorPlanSourceType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                Text(sourceType.title)
                    .font(.headline)
                Text(sourceType.description)
                    .font(.body)
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .background(
            isSelected ? Color(.systemGray6) : .clear,
            in: RoundedRectangle(cornerRadius: 10)
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("선택하면 계속 버튼이 활성화됩니다")
    }
}


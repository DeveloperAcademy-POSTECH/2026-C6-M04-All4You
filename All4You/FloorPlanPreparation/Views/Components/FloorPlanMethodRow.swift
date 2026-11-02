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
    
    private let shape = RoundedRectangle(cornerRadius: 16)
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                Text(sourceType.title)
                    .font(.headline)
                Text(sourceType.description)
                    .font(.body)
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .background(.white, in: shape)
            .overlay {
                shape.strokeBorder(isSelected ? .black : .clear, lineWidth: 2)
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("선택하면 계속 버튼이 활성화됩니다")
    }
}


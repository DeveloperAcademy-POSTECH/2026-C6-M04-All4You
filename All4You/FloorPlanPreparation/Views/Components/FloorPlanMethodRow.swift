//
//  FloorPlanMethodRow.swift
//  All4You
//
//  Created by 채유성 on 11/1/26.
//

// 평면도 불러오는 방식 선택 리스트 컴포넌트
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
                    .animation(.linear(duration: 0.15), value: isSelected)
            }
            .contentShape(shape)
        }
        .buttonStyle(FloorPlanMethodPressStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("선택하면 계속 버튼이 활성화됩니다")
    }
}

// 시스템의 기본 버튼 애니메이션 전환 효과를 막고 테두리에만 변경을 주기 위한 함수
private struct FloorPlanMethodPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}


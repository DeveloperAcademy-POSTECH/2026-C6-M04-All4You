//
//  FloorPlanPreparationHeader.swift
//  All4You
//
//  Created by 채유성 on 11/1/26.
//

// 이전 버튼 & 주소 & 시간 컴포넌트
import SwiftUI

struct FloorPlanPreparationHeader: View {
    let address: String
    let createdAt: Date
    let onBack: () -> Void
    
    var body: some View {
        HStack(spacing: 14) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 48, height: 48)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: Circle())
            .accessibilityLabel("이전")
            
            VStack(alignment: .leading, spacing: 1) {
                Text(address)
                    .font(.system(size: 22, weight: .semibold))
                Text(createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

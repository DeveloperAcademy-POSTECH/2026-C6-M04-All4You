//
//  FloorPlanMemoSplitHandle.swift
//  All4You
//
//  메모 목록과 상세 화면 사이의 드래그 가능한 구분선
//

import SwiftUI

struct FloorPlanMemoSplitHandle: View {
    var body: some View {
        Rectangle()
            .fill(Color(.separator).opacity(0.6))
            .frame(width: 1)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .accessibilityLabel("메모 목록 너비")
            .accessibilityHint("위아래로 쓸어 너비를 조절합니다")
    }
}

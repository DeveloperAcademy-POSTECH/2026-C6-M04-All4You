//
//  PhotoTakenAtLabel.swift
//  All4You
//
//  Created by SIA on 11/15/26.
//

import SwiftUI

/// 사진의 촬영 날짜와 시간을 표시하는 공통 컴포넌트
struct PhotoTakenAtLabel: View {
    let date: Date

    var body: some View {
        HStack(spacing: 16) {
            Text(date, format: .dateTime.year().month().day())
            Text(date, format: .dateTime.hour().minute())
        }
        .font(AppTypography.subheadline)
        .foregroundStyle(.secondary)
        .environment(\.locale, Locale(identifier: "ko_KR"))
    }
}

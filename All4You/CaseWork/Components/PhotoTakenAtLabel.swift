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

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd."
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter
    }()

    var body: some View {
        HStack(spacing: 16) {
            Text(Self.dateFormatter.string(from: date))
            Text(date, format: .dateTime.hour().minute())
        }
        .font(AppTypography.subheadline)
        .foregroundStyle(.secondary)
        .environment(\.locale, Locale(identifier: "ko_KR"))
    }
}

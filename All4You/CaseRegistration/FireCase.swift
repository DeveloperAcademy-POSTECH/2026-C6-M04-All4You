//
//  FireCase.swift
//  All4You
//
//  Created by SIA on 11/4/26.
//
//  SwiftData에 저장하는 화재 사건 모델
//

import Foundation
import SwiftData

@Model
final class FireCase {
    @Attribute(.unique) var id: UUID
    var address: String
    var occurredAt: Date

    // SwiftData에 문자열로 저장하고 UI에는 타입 안전한 enum 제공
    private var statusValue: String
    var lastViewedAt: Date
    var photoCount: Int
    var memoCount: Int

    var status: Status {
        get { Status(rawValue: statusValue) ?? .inProgress }
        set { statusValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        address: String,
        occurredAt: Date,
        status: Status = .inProgress,
        lastViewedAt: Date = .now,
        photoCount: Int = 0,
        memoCount: Int = 0
    ) {
        self.id = id
        self.address = address
        self.occurredAt = occurredAt
        self.statusValue = status.rawValue
        self.lastViewedAt = lastViewedAt
        self.photoCount = photoCount
        self.memoCount = memoCount
    }

    var title: String {
        address.split(separator: " ").suffix(2).joined(separator: " ")
    }

    enum Status: String {
        case inProgress
        case closed
    }
}

// 사이드바 분류는 저장 대상이 아닌 UI 상태
// enum 케이스명은 기존 화면과 호환되도록 유지
enum CaseFilter: CaseIterable, Hashable {
    case recent, inProgress, closed

    var title: String {
        switch self {
        case .recent: "최근 열람"
        case .inProgress: "조사 중"
        case .closed: "조사 종결"
        }
    }

    var systemImage: String {
        switch self {
        case .recent: "clock"
        case .inProgress: "waveform.path.ecg"
        case .closed: "checkmark"
        }
    }
}

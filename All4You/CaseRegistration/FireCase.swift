//
//  FileCase.swift
//  All4You
//
//  Created by SIA on 11/4/26.
//

// 사건 한 건과 사건 목록의 분류

import Foundation

/// 화재 사건 한 건
// TEMP: 데이터 저장 방식이 정해지기 전 임시 모델 — ERD(Investigation)가 확정되면 이름·필드를 맞춰야 함
struct FireCase: Identifiable, Hashable {
    let id: UUID
    /// 도로명 전체 주소. 예) 경상북도 포항시 남구 청암로 77
    var address: String
    /// 출동 날짜와 시간
    var occurredAt: Date
    var status: Status
    var lastViewedAt: Date
    var photoCount: Int
    var memoCount: Int

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
        self.status = status
        self.lastViewedAt = lastViewedAt
        self.photoCount = photoCount
        self.memoCount = memoCount
    }

    /// 목록에 보여 줄 짧은 이름. 주소의 마지막 두 마디를 쓴다. 예) 청암로 77
    var title: String {
        address.split(separator: " ").suffix(2).joined(separator: " ")
    }

    enum Status {
        case inProgress, closed
    }
}

/// 사이드바에서 고르는 사건 목록의 분류
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

extension FireCase {
    /// 미리보기용 예시 사건
    static let samples: [FireCase] = {
        let entries: [(String, String, FireCase.Status)] = [
            ("경상북도 포항시 북구 두호동 128", "2026-09-28 14:36", .inProgress),
            ("경상북도 포항시 북구 장성동 305", "2026-09-22 08:15", .inProgress),
            ("경상북도 포항시 북구 죽도동 74", "2026-09-17 19:42", .inProgress),
            ("경상북도 포항시 북구 양덕동 219", "2026-09-11 03:27", .inProgress),
            ("경상북도 포항시 북구 흥해읍 462", "2026-09-10 11:53", .inProgress),
            ("경상북도 포항시 남구 오천읍 156", "2026-08-27 22:18", .closed),
            ("경상북도 포항시 남구 연일읍 83", "2026-08-21 10:04", .closed),
            ("경상북도 포항시 남구 대잠동 241", "2026-08-16 16:39", .closed),
            ("경상북도 포항시 남구 효자동 67", "2026-08-09 01:52", .closed),
            ("경상북도 포항시 북구 우현동 194", "2026-08-03 13:25", .closed),
        ]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return entries.map { address, date, status in
            let occurredAt = formatter.date(from: date) ?? .now
            return FireCase(
                address: address,
                occurredAt: occurredAt,
                status: status,
                lastViewedAt: occurredAt,
                photoCount: 47,
                memoCount: 12
            )
        }
    }()
}

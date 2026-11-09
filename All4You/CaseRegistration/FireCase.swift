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
    // TODO: 사진 및 메모 모델 연결 후 실제 데이터 개수로 대체
    // 현재는 관계 데이터가 연결되지 않아 개수를 별도로 저장함.
    // 추후 @Relationship을 통해 연결된 사진 및 메모의 count를 사용하도록 변경 예정.
    var photoCount: Int
    var memoCount: Int

    /// 조사 차수. 사건을 지우면 함께 지운다
    @Relationship(deleteRule: .cascade, inverse: \InvestigationSession.fireCase)
    var sessions: [InvestigationSession] = []

    /// 평면도 (사건 하나에 하나, 아직 없을 수 있음). 사건을 지우면 함께 지운다
    @Relationship(deleteRule: .cascade, inverse: \FloorPlan.fireCase)
    var floorPlan: FloorPlan?

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

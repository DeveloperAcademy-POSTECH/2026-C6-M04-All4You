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
    /// 상세 주소 (동·호수 등). 입력하지 않으면 빈 문자열
    var detailAddress: String = ""
    /// 사건명. 등록할 때 주소·상세 주소로 자동으로 채우고, 직접 고칠 수 있다. 예전에 등록한 사건은 빈 문자열
    var caseName: String = ""
    var occurredAt: Date
    
    // SwiftData에 문자열로 저장하고 UI에는 타입 안전한 enum 제공
    private var statusValue: String
    var lastViewedAt: Date
    
    /// 조사 차수. 사건을 지우면 함께 지운다
    @Relationship(deleteRule: .cascade, inverse: \InvestigationSession.fireCase)
    var sessions: [InvestigationSession] = []
    
    /// 현장 사진. 사건을 지우면 함께 지운다
    @Relationship(deleteRule: .cascade, inverse: \EvidencePhoto.fireCase)
    var photos: [EvidencePhoto] = []

    /// 메모. 사건을 지우면 함께 지운다
    @Relationship(deleteRule: .cascade, inverse: \Memo.fireCase)
    var memos: [Memo] = []
    
    /// 평면도 (사건 하나에 하나, 아직 없을 수 있음). 사건을 지우면 함께 지운다
    @Relationship(deleteRule: .cascade, inverse: \FloorPlan.fireCase)
    var floorPlan: FloorPlan?
    
    /// 사용자가 만든 사건 목록. 사건은 목록 하나에만 들어가고, nil이면 상태에 따라 조사 중·조사 종결에 보인다
    var folder: CaseFolder?
    
    var status: Status {
        get { Status(rawValue: statusValue) ?? .inProgress }
        set { statusValue = newValue.rawValue }
    }
    
    init(
        id: UUID = UUID(),
        address: String,
        detailAddress: String = "",
        caseName: String = "",
        occurredAt: Date,
        status: Status = .inProgress,
        lastViewedAt: Date = .now
    ) {
        self.id = id
        self.address = address
        self.detailAddress = detailAddress
        self.caseName = caseName
        self.occurredAt = occurredAt
        self.statusValue = status.rawValue
        self.lastViewedAt = lastViewedAt
    }
    
    /// 목록에 보이는 이름. 사건명이 있으면 사건명, 사건명이 없던 예전 사건은 주소의 도로명·번지 ("청암로 77")
    var title: String {
        guard caseName.isEmpty else { return caseName }
        return Self.shortAddress(address)
    }
    
    enum Status: String {
        case inProgress
        case closed
    }
}

// 사이드바 분류는 저장 대상이 아닌 UI 상태
// enum 케이스명은 기존 화면과 호환되도록 유지
enum CaseFilter: CaseIterable, Hashable {
    case recent, inProgress
    
    var title: String {
        switch self {
        case .recent: "최근 열람"
        case .inProgress: "조사 중"
        }
    }
    
    var systemImage: String {
        switch self {
        case .recent: "clock"
        case .inProgress: "waveform.path.ecg"
        }
    }
}

/// 사용자가 만든 사건 목록 (사이드바의 폴더). 조사 중·조사 종결은 기본 목록이라 저장하지 않는다
@Model
final class CaseFolder {
    @Attribute(.unique) var id: UUID
    var name: String
    /// 사이드바에서 놓인 순서. 작을수록 위
    var sortOrder: Int
    var createdAt: Date
    
    /// 이 목록에 넣은 사건. 목록을 지우면 사건은 지우지 않고 목록에서만 뺀다 (상태에 따라 조사 중·조사 종결에 다시 보인다)
    @Relationship(deleteRule: .nullify, inverse: \FireCase.folder)
    var cases: [FireCase] = []
    
    init(id: UUID = UUID(), name: String, sortOrder: Int, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }
}

/// 사이드바에서 고른 목록. 기본 목록(최근 열람·조사 중·조사 종결) 또는 사용자가 만든 목록
enum CaseListSelection: Hashable {
    case filter(CaseFilter)
    /// CaseFolder.id
    case folder(UUID)
}

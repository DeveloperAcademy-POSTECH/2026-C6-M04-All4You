//
//  CaseStore.swift
//  All4You
//
//  Created by SIA on 11/4/26.
//

// 사건 목록을 들고 있는 저장소. 화면들이 environment로 함께 본다

import Foundation
import Observation

@Observable
final class CaseStore {
    // TEMP: 데이터 저장 방식이 정해지기 전이라 메모리에만 둔다 — 앱을 끄면 사라짐
    private(set) var cases: [FireCase]

    init(cases: [FireCase] = []) {
        self.cases = cases
    }

    func add(_ fireCase: FireCase) {
        cases.append(fireCase)
    }

    /// 사건을 열어 본 시각을 남긴다. 최근 열람 순서에 쓰인다
    func markViewed(_ id: FireCase.ID) {
        guard let index = cases.firstIndex(where: { $0.id == id }) else { return }
        cases[index].lastViewedAt = .now
    }

    func count(of status: FireCase.Status) -> Int {
        cases.filter { $0.status == status }.count
    }

    /// 분류와 검색어에 맞는 사건. 최근 열람은 열어 본 순, 나머지는 출동 시각 최신순
    func cases(for filter: CaseFilter, matching query: String = "") -> [FireCase] {
        let keyword = query.trimmingCharacters(in: .whitespaces)
        let searched = keyword.isEmpty
            ? cases
            : cases.filter { $0.address.localizedStandardContains(keyword) }

        switch filter {
        case .recent:
            return searched.sorted { $0.lastViewedAt > $1.lastViewedAt }
        case .inProgress:
            return searched.filter { $0.status == .inProgress }.sorted { $0.occurredAt > $1.occurredAt }
        case .closed:
            return searched.filter { $0.status == .closed }.sorted { $0.occurredAt > $1.occurredAt }
        }
    }
}

/// 같은 달에 출동한 사건 묶음
struct MonthSection: Identifiable {
    /// 그 달의 첫날
    let month: Date
    let cases: [FireCase]

    var id: Date { month }

    /// 최신순으로 정렬된 사건을 달별로 묶는다
    static func group(_ cases: [FireCase], calendar: Calendar = .current) -> [MonthSection] {
        var sections: [MonthSection] = []
        for fireCase in cases {
            let month = calendar.dateInterval(of: .month, for: fireCase.occurredAt)?.start ?? fireCase.occurredAt
            if let last = sections.last, last.month == month {
                sections[sections.count - 1] = MonthSection(month: month, cases: last.cases + [fireCase])
            } else {
                sections.append(MonthSection(month: month, cases: [fireCase]))
            }
        }
        return sections
    }
}

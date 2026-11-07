//
//  CaseStore.swift
//  All4You
//
//  Created by SIA on 11/4/26.
//

import Foundation

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

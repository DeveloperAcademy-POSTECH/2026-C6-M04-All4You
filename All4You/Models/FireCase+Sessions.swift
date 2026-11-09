// 사건의 조사 차수를 읽고 새 차수를 만드는 규칙

import Foundation

extension FireCase {
    /// 사건의 조사 차수 번호를 1차부터 차례로
    var sessionNumbers: [Int] {
        sessions.map(\.sessionNumber).sorted()
    }

    /// 가장 큰 차수 다음 번호로 새 차수를 만들어 붙이고 그 번호를 돌려준다. 차수가 없으면 1차를 만든다
    @discardableResult
    func addSession() -> Int {
        let nextNumber = (sessionNumbers.last ?? 0) + 1
        sessions.append(InvestigationSession(sessionNumber: nextNumber))
        return nextNumber
    }
}

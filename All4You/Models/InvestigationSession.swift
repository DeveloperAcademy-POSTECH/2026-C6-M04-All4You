// SwiftData에 저장하는 조사 차수 모델. 같은 사건을 다시 조사할 때마다 차수가 하나씩 늘어난다

import Foundation
import SwiftData

/// 사건의 조사 차수 하나 (1차, 2차 …)
@Model
final class InvestigationSession {
    var sessionNumber: Int
    /// 이 차수가 속한 사건. 반대쪽은 `FireCase.sessions`
    var fireCase: FireCase?
    /// 이 차수에 찍은 사진. 차수가 없어져도 사진은 사건에 남는다
    @Relationship(deleteRule: .nullify, inverse: \EvidencePhoto.session)
    var photos: [EvidencePhoto] = []

    init(sessionNumber: Int, fireCase: FireCase? = nil) {
        self.sessionNumber = sessionNumber
        self.fireCase = fireCase
    }
}

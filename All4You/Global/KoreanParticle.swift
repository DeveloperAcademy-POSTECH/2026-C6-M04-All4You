// 한국어 조사를 앞 글자의 받침에 맞춰 붙이는 도우미. "발화지점은", "피해자는"처럼 문구에 이름을 끼워 넣을 때 쓴다

/// 받침 유무에 따라 모양이 바뀌는 조사
enum KoreanParticle {
    /// 은/는
    case topic
    /// 이/가
    case subject
    /// 을/를
    case object
    /// 과/와
    case with
    /// 으로/로 (ㄹ 받침은 "로")
    case direction

    /// 받침이 있을 때와 없을 때의 모양
    fileprivate var forms: (withFinal: String, withoutFinal: String) {
        switch self {
        case .topic: ("은", "는")
        case .subject: ("이", "가")
        case .object: ("을", "를")
        case .with: ("과", "와")
        case .direction: ("으로", "로")
        }
    }
}

extension String {
    /// 이 글자 뒤에 조사를 받침에 맞게 붙인 글자. 예: "발화지점".appending(.topic) → "발화지점은", "피해자".appending(.topic) → "피해자는".
    /// 마지막 글자가 한글이 아니면(숫자·영어 등) 받침이 없는 모양을 쓴다
    func appending(_ particle: KoreanParticle) -> String {
        let forms = particle.forms
        guard let finalIndex = lastFinalConsonantIndex else { return self + forms.withoutFinal }
        // 으로/로는 받침이 없거나 ㄹ(8번)이면 "로"
        if particle == .direction, finalIndex == Self.rieulIndex { return self + forms.withoutFinal }
        return self + (finalIndex == 0 ? forms.withoutFinal : forms.withFinal)
    }

    /// 마지막 한글 글자의 받침 번호 (0이면 받침 없음). 한글이 아니면 nil
    private var lastFinalConsonantIndex: Int? {
        guard let scalar = unicodeScalars.last, (0xAC00...0xD7A3).contains(scalar.value) else { return nil }
        // 한글 완성형은 (초성 × 21 + 중성) × 28 + 받침 순서로 놓여 있어, 28로 나눈 나머지가 받침 번호다
        return Int(scalar.value - 0xAC00) % 28
    }

    /// 받침 번호 중 ㄹ
    private static let rieulIndex = 8
}

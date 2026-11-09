// 사건 주소를 정리하고 짧게 줄이는 규칙. 등록 화면의 사건명 자동 생성과 목록 제목이 함께 쓴다

import Foundation

extension FireCase {
    /// 저장할 주소로 정리한다.
    /// 현재 위치에서 받은 주소(MapKit fullAddress)는 줄바꿈·쉼표가 섞이고 끝에 우편번호가 붙을 수 있어,
    /// 그대로 두면 목록 제목(주소 뒤 단어)이 "77 37673"처럼 숫자만 남는다
    static func cleanedAddress(_ address: String) -> String {
        var words = address
            .replacingOccurrences(of: ",", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
        // 끝에 붙은 우편번호(숫자 5자리)를 뗀다
        while let last = words.last, isPostalCode(last) {
            words.removeLast()
        }
        return words.joined(separator: " ")
    }

    /// 주소에서 도로명과 건물 번호만 ("경상북도 포항시 남구 청암로 77" → "청암로 77").
    /// 도로명(…로·…길)을 못 찾으면 숫자만 있는 단어를 뺀 마지막 두 단어
    static func shortAddress(_ address: String) -> String {
        let words = cleanedAddress(address).split(separator: " ").map(String.init)
        if let roadIndex = words.lastIndex(where: isRoadName) {
            return words[roadIndex...].prefix(2).joined(separator: " ")
        }
        let meaningful = words.filter { !$0.allSatisfy(\.isNumber) }
        return (meaningful.isEmpty ? words : meaningful).suffix(2).joined(separator: " ")
    }

    /// 사건명 자동 생성: "청암로 77 1층 207호 화재". 주소가 없으면 빈 문자열
    static func autoCaseName(address: String, detailAddress: String) -> String {
        let road = shortAddress(address)
        guard !road.isEmpty else { return "" }
        let detail = detailAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        return [road, detail, Copy.fireSuffix].filter { !$0.isEmpty }.joined(separator: " ")
    }

    private static func isPostalCode(_ word: String) -> Bool {
        word.count == 5 && word.allSatisfy(\.isNumber)
    }

    /// 도로명 주소의 도로 이름 (청암로, 테헤란로, 중앙대로, 신촌로2길, 해운대해변로123번길 …)
    private static func isRoadName(_ word: String) -> Bool {
        word.count >= 2 && (word.hasSuffix("로") || word.hasSuffix("길"))
    }

    private enum Copy {
        static let fireSuffix = "화재"
    }
}

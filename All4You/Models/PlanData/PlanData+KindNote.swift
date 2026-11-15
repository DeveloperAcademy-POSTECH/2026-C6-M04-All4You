// 종류가 기타인 스탬프의 라벨 글자(kindNote)를 고치는 계산

import Foundation

extension PlanData {
    /// 라벨 글자 길이 한계 (글자 수)
    // TEMP: 라벨이 너무 길어지지 않게 20자로 임시로 정함
    static let kindNoteMaxLength = 20

    /// 종류가 기타인 스탬프(PlanMarker.id·WallFixture.id)의 라벨 글자를 바꾼다.
    /// 앞뒤 빈칸을 빼고 한계 길이로 자르며, 비어 있으면 글자를 지워 "기타"로 돌아가게 한다. 기타가 아니거나 없는 스탬프는 바꾸지 않는다
    mutating func setKindNote(id: String, to text: String) {
        let trimmed = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.kindNoteMaxLength))
        let note = trimmed.isEmpty ? nil : trimmed
        if let index = markers.firstIndex(where: { $0.id == id }), markers[index].isKindOther {
            markers[index].kindNote = note
        } else if let index = wallFixtures.firstIndex(where: { $0.id == id }), wallFixtures[index].isKindOther {
            wallFixtures[index].kindNote = note
        }
    }

    /// 종류가 기타인 스탬프에 지금 적힌 라벨 글자. 적은 것이 없거나 기타가 아니면 nil
    func kindNote(id: String) -> String? {
        if let marker = markers.first(where: { $0.id == id }), marker.isKindOther { return marker.kindNote }
        if let fixture = wallFixtures.first(where: { $0.id == id }), fixture.isKindOther { return fixture.kindNote }
        return nil
    }

    /// 라벨 글자를 직접 적을 수 있는 스탬프(종류가 기타)인지
    func isKindOther(id: String) -> Bool {
        markers.first(where: { $0.id == id })?.isKindOther ?? wallFixtures.first(where: { $0.id == id })?.isKindOther ?? false
    }
}

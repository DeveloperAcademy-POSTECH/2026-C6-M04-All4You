// 직접 그리기 스케치 위에 놓는 스탬프. 화면 상태라 저장하지 않고, 변환이 끝나면 도면 좌표로 옮겨 넣는다
// 칸 이름은 PlanMarker를 따른다 (kind·ignitionCause·electricalKind·kindNote)

import Foundation

/// 스케치 위 스탬프 하나. 위치는 스케치(캔버스) 점이다
struct SketchStamp: Identifiable, Equatable {
    let id: String
    /// 발화지점·피해자·전기. 전기는 변환 때 벽에 놓을지 바닥에 놓을지 정한다 (MarkerKind.outlet)
    var kind: MarkerKind
    var ignitionCause: IgnitionCause?
    var electricalKind: ElectricalKind?
    /// 종류가 기타일 때 적은 라벨 글자 (PlanMarker.kindNote와 같은 뜻)
    var kindNote: String?
    /// 스케치(캔버스) 점
    var position: CGPoint

    /// 종류가 기타라 라벨 글자를 직접 적을 수 있는지
    var isKindOther: Bool {
        switch kind {
        case .ignitionPoint: ignitionCause == .other
        case .outlet: electricalKind == .other
        case .person: false
        }
    }

    /// 스탬프 아래에 보일 글자. PlanMarker.kindLabel과 같은 규칙이다
    var kindLabel: String? {
        if isKindOther, let kindNote { return kindNote }
        return switch kind {
        case .ignitionPoint: ignitionCause?.title
        case .outlet: electricalKind?.title
        case .person: EditTool.person.title
        }
    }

    /// 도구 막대에서 고른 도구·종류로 새 스탬프를 만든다. 스탬프 도구가 아니면 nil
    init?(tool: EditTool, option: StampOption?, position: CGPoint) {
        switch tool {
        case .ignitionPoint: kind = .ignitionPoint
        case .outlet: kind = .outlet
        case .person: kind = .person
        case .roomName, .furniture, .window, .door: return nil
        }
        id = UUID().uuidString
        if case .ignitionCause(let cause)? = option { ignitionCause = cause }
        if case .electricalKind(let electrical)? = option { electricalKind = electrical }
        self.position = position
    }

    /// 글자를 적었다. 앞뒤 빈칸을 빼고 한계 길이로 자르며, 비어 있으면 지워 "기타"로 돌아가게 한다. 기타가 아니면 바꾸지 않는다
    mutating func setKindNote(_ text: String) {
        guard isKindOther else { return }
        let trimmed = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(PlanData.kindNoteMaxLength))
        kindNote = trimmed.isEmpty ? nil : trimmed
    }
}

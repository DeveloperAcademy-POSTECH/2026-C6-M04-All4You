// 3D 이름 라벨(공간·스탬프 종류·가구)이 화면에서 서로 겹쳐 보이면 우선순위가 높은 것만 남긴다.
// 라벨은 3D 점을 화면 점으로 바꿔 위에 겹치는 SwiftUI 뷰라, 화면 위 모양(사각형)끼리 겹침을 본다

import SwiftUI

enum LabelDeclutter {
    /// 라벨 종류. 앞에 있을수록 먼저 남긴다 (앨범 라벨(사진 핀) → 공간 → 스탬프 종류 → 가구)
    enum Kind: CaseIterable {
        case pin
        case room
        case stamp
        case furniture
    }

    /// 라벨 하나를 가리키는 키. 종류가 다르면 id가 같아도 다른 라벨이다
    struct Key: Hashable {
        let kind: Kind
        let id: String
    }

    /// 화면에 자리가 잡힌 라벨의 가운데와 크기(pt)
    struct Slot {
        let key: Key
        let center: CGPoint
        let size: CGSize
    }

    /// 겹침을 볼 때 라벨 크기에 곱하는 비율. 1보다 작아서, 가장자리만 살짝 닿는 정도로는 숨기지 않고 꽤 겹쳐야 숨긴다
    // TEMP: 실기기에서 라벨을 겹쳐 보며 정함
    static let overlapTolerance: CGFloat = 0.7

    /// 라벨 글자 크기(pt)와 여백으로 캡슐 크기를 어림한다. 한글·기호는 글자 크기만큼, 라틴 글자·숫자는 0.6배. scale은 도면 배율에 따른 라벨 배율
    static func estimatedSize(of text: String, fontSize: CGFloat, horizontalPadding: CGFloat, verticalPadding: CGFloat, scale: CGFloat) -> CGSize {
        let textWidth = text.reduce(CGFloat(0)) { $0 + ($1.isASCII ? fontSize * 0.6 : fontSize) }
        return CGSize(
            width: (textWidth + horizontalPadding * 2) * scale,
            height: (fontSize * 1.3 + verticalPadding * 2) * scale
        )
    }

    /// 종류 우선순위대로 훑어, 먼저 남긴 라벨과 겹치지 않는 것만 남긴 키들. 같은 종류끼리는 넘겨받은 순서대로 남긴다
    static func visibleKeys(_ slots: [Slot]) -> Set<Key> {
        let ordered = slots.enumerated().sorted { a, b in
            let rankA = Kind.allCases.firstIndex(of: a.element.key.kind) ?? .max
            let rankB = Kind.allCases.firstIndex(of: b.element.key.kind) ?? .max
            return rankA == rankB ? a.offset < b.offset : rankA < rankB
        }
        var kept: [CGRect] = []
        var keys = Set<Key>()
        for (_, slot) in ordered {
            let width = slot.size.width * overlapTolerance
            let height = slot.size.height * overlapTolerance
            let rect = CGRect(x: slot.center.x - width / 2, y: slot.center.y - height / 2, width: width, height: height)
            guard !kept.contains(where: { $0.intersects(rect) }) else { continue }
            kept.append(rect)
            keys.insert(slot.key)
        }
        return keys
    }
}

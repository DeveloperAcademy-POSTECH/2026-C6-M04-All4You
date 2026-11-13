// 치수 글자가 서로 겹치지 않게 솎아 내고, 종류마다 색을 달리해 어떤 것의 치수인지 구분하게 돕는다.
// 2D·3D 수정 화면(추후 메인·Export)이 같은 규칙을 쓴다

import SwiftUI

extension DimensionKind {
    /// 겹칠 때 먼저 남기는 순서 (앞일수록 먼저). 공간·벽처럼 큰 것을 먼저, 창문·문처럼 작은 것을 나중에 남긴다
    static let priorityOrder: [DimensionKind] = [.room, .wall, .furniture, .victim, .opening]

    /// 이 종류의 선·글자 색. 벽은 회색, 나머지는 주황이라 벽에 붙은 창문·문 선과도 구분된다
    var color: Color {
        self == .wall ? .gray700 : .orange700
    }

    /// 3D 선에 쓰는 같은 색
    var uiColor: UIColor {
        UIColor(resource: self == .wall ? .gray700 : .orange700)
    }
}

/// 글자 자리 하나. 가운데와 크기(pt)
struct DimensionSlot {
    let id: String
    let kind: DimensionKind
    let center: CGPoint
    let size: CGSize
}

enum DimensionDeclutter {
    /// 글자 크기(pt)를 글자 수로 어림한다. 한글·기호는 글자 크기만큼, 라틴 글자·숫자는 0.6배. 윤곽 여유를 더한다
    static func estimatedSize(of text: String, fontSize: CGFloat = 12, scale: CGFloat) -> CGSize {
        let width = text.reduce(CGFloat(0)) { $0 + ($1.isASCII ? fontSize * 0.6 : fontSize) }
        return CGSize(width: (width + 6) * scale, height: (fontSize * 1.3 + 4) * scale)
    }

    /// 종류 우선순위대로 훑어, 먼저 남긴 글자와 겹치지 않는 것만 남긴 id들
    static func visibleIds(_ slots: [DimensionSlot]) -> Set<String> {
        var kept: [CGRect] = []
        var ids = Set<String>()
        let ordered = slots.enumerated().sorted { a, b in
            let rankA = DimensionKind.priorityOrder.firstIndex(of: a.element.kind) ?? .max
            let rankB = DimensionKind.priorityOrder.firstIndex(of: b.element.kind) ?? .max
            return rankA == rankB ? a.offset < b.offset : rankA < rankB
        }
        for (_, slot) in ordered {
            let rect = CGRect(x: slot.center.x - slot.size.width / 2, y: slot.center.y - slot.size.height / 2, width: slot.size.width, height: slot.size.height)
            guard !kept.contains(where: { $0.intersects(rect) }) else { continue }
            kept.append(rect)
            ids.insert(slot.id)
        }
        return ids
    }
}

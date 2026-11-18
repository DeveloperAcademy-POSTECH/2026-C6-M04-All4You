// 쇼케이스용: 안내 중인 스탬프 도구를 켜 두면 도면에 놓는 방법을 문구로 알려 준다. 모양은 수정 화면의 안내 캡슐과 같다

import SwiftUI

struct StampGuideHint: View {
    let tool: EditTool
    /// 종류를 고르는 도구(전기·발화지점)에서 종류를 이미 골랐는지
    let hasPickedOption: Bool

    var body: some View {
        Text(message)
            .font(AppTypography.subheadline)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.vertical, Layout.verticalPadding)
            .frame(maxWidth: Layout.maxWidth)
            .background(Color.gray900, in: .rect(cornerRadius: Layout.cornerRadius))
            .allowsHitTesting(false)
    }

    /// 종류를 먼저 골라야 놓을 수 있는 도구는 종류를 고르기 전과 후의 문구가 다르다
    private var message: String {
        switch tool {
        case .person: Copy.placePerson
        case .outlet: hasPickedOption ? Copy.placeOutlet : Copy.pickOutletKind
        case .ignitionPoint: hasPickedOption ? Copy.placeIgnitionPoint : Copy.pickIgnitionCause
        case .roomName, .furniture, .window, .door: ""
        }
    }
}

// 크기
extension StampGuideHint {
    private enum Layout {
        static let maxWidth: CGFloat = 560
        static let cornerRadius: CGFloat = 22
        static let horizontalPadding: CGFloat = 20
        static let verticalPadding: CGFloat = 8
    }
}

// 문구
extension StampGuideHint {
    private enum Copy {
        static let placePerson = "도면을 눌러 피해자를 놓아 보세요"
        static let pickOutletKind = "전기 종류를 고른 뒤 도면을 눌러 놓아 보세요"
        static let placeOutlet = "도면을 눌러 전기를 놓아 보세요"
        static let pickIgnitionCause = "발화 원인을 고른 뒤 도면을 눌러 놓아 보세요"
        static let placeIgnitionPoint = "도면을 눌러 발화지점을 놓아 보세요"
    }
}

#Preview {
    VStack(spacing: 12) {
        StampGuideHint(tool: .person, hasPickedOption: false)
        StampGuideHint(tool: .outlet, hasPickedOption: false)
        StampGuideHint(tool: .outlet, hasPickedOption: true)
        StampGuideHint(tool: .ignitionPoint, hasPickedOption: false)
        StampGuideHint(tool: .ignitionPoint, hasPickedOption: true)
    }
    .padding(40)
}

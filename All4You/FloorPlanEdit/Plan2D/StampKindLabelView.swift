// 스탬프(발화지점·전기) 아래에 띄우는 종류 글자 캡슐. 스탬프와 같은 주황 바탕이라 흰 바탕의 가구 이름 캡슐·검은 바탕의 공간 이름 캡슐과 구분된다

import SwiftUI

/// 고른 종류("방화", "멀티탭")를 보여 주는 캡슐. 눌리지 않는다
struct StampKindLabelView: View {
    /// PlanMarker.kindLabel · WallFixture.kindLabel
    let text: String
    /// 도면 확대·축소에 맞춰 키우고 줄이는 배율 (LabelScale). 1이면 기본 크기
    var scale: CGFloat = 1

    var body: some View {
        Text(text)
            .font(.system(size: Layout.fontSize, weight: .semibold))
            .foregroundStyle(.white)
            .fixedSize()
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.vertical, Layout.verticalPadding)
            .background(.brand500, in: .capsule)
            .scaleEffect(scale)
    }

    /// 배율 1일 때 캡슐 높이 (pt). 스탬프 아래에 놓을 자리를 셈할 때 쓴다
    static let height = Layout.fontSize * 1.2 + Layout.verticalPadding * 2
}

// 레이아웃 값
extension StampKindLabelView {
    private enum Layout {
        // TEMP: Figma에 없어 스탬프와 같은 주황 바탕·흰 글자로 가구 이름 캡슐(글자 12·여백 13×7.5)보다 조금 작게 임시로 정함 — 디자인 확인 필요
        static let fontSize: CGFloat = 11
        static let horizontalPadding: CGFloat = 9
        static let verticalPadding: CGFloat = 4
    }
}

#Preview {
    StampKindLabelView(text: "멀티탭")
}

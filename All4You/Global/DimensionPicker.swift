// 도면을 2D(평면)로 볼지 3D(입체)로 볼지 고르는 공용 전환 막대

import SwiftUI

/// 도면을 평면으로 볼지 입체로 볼지
enum PlanDimension: CaseIterable {
    case twoD, threeD

    var title: String {
        switch self {
        case .twoD: "2D"
        case .threeD: "3D"
        }
    }
}

/// 2D·3D 화면 하나를 겹쳐 둘 때 쓰는 층. 보이지 않는 층은 투명하고 눌리지 않는다.
/// 2D와 3D를 계속 띄워 두고 이 층의 투명도만 바꿔 서로 서서히 바뀌게 한다 (도면 수정 화면과 메인 도면 탭이 함께 쓴다)
struct DimensionLayer: ViewModifier {
    let isShown: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isShown ? 1 : 0)
            .allowsHitTesting(isShown)
            .accessibilityHidden(!isShown)
    }
}

/// 2D/3D 중 하나를 고르는 막대. 고르는 순간 막대가 스스로 애니메이션을 걸어서,
/// 어느 화면에서 써도 선택 칸의 유리 애니메이션이 똑같이 나온다
struct DimensionPicker: View {
    @Binding var selection: PlanDimension

    var body: some View {
        Picker(Copy.label, selection: animatedSelection) {
            ForEach(PlanDimension.allCases, id: \.self) { dimension in
                Text(dimension.title).tag(dimension)
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.large)
        .frame(width: Layout.width)
    }

    /// 고른 값을 바꿀 때 애니메이션 범위 안에서 바꾼다
    private var animatedSelection: Binding<PlanDimension> {
        Binding(
            get: { selection },
            set: { newValue in
                withAnimation(.easeInOut(duration: Layout.animationDuration)) {
                    selection = newValue
                }
            }
        )
    }
}

// 크기
extension DimensionPicker {
    private enum Layout {
        // 글자에 비해 막대가 커 보여 줄임. 메인 도면 탭과 도면 수정 화면이 이 크기를 함께 쓴다
        static let width: CGFloat = 240
        /// 선택을 바꿀 때 애니메이션 시간 (초)
        static let animationDuration = 0.3
    }
}

// 문구
extension DimensionPicker {
    private enum Copy {
        static let label = "도면 보기 방식"
    }
}

#Preview {
    @Previewable @State var selection = PlanDimension.twoD

    DimensionPicker(selection: $selection)
}

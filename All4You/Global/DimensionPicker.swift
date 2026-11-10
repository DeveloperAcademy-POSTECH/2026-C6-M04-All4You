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

/// 2D/3D 중 하나를 고르는 리퀴드 글래스 막대. 고른 칸이 두 칸 사이를 물방울처럼 옮겨 다닌다.
/// 메인 도면 탭과 도면 수정 화면이 함께 쓴다
struct DimensionPicker: View {
    @Binding var selection: PlanDimension

    @Namespace private var namespace

    var body: some View {
        GlassEffectContainer {
            HStack(spacing: 0) {
                ForEach(PlanDimension.allCases, id: \.self) { dimension in
                    segment(dimension)
                }
            }
            .padding(Layout.inset)
            .glassEffect(.regular, in: Capsule())
        }
        .frame(width: Layout.width, height: Layout.height)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Copy.label)
    }

    private func segment(_ dimension: PlanDimension) -> some View {
        let isSelected = selection == dimension
        return Button {
            withAnimation(.smooth) {
                selection = dimension
            }
        } label: {
            Text(dimension.title)
                .font(AppTypography.headline)
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .background {
            // 고른 칸의 주황 유리. 같은 id라 다른 칸으로 옮겨 갈 때 이어져 움직인다
            if isSelected {
                Capsule()
                    .fill(.clear)
                    .glassEffect(.regular.tint(.brand500), in: Capsule())
                    .glassEffectID(Copy.selectedID, in: namespace)
            }
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// 크기
extension DimensionPicker {
    private enum Layout {
        static let width: CGFloat = 370
        /// 애플 기본 가장 큰 막대(.extraLarge) 높이와 같다 (Figma 27:7166)
        static let height: CGFloat = 50
        /// 바깥 막대 가장자리에서 고른 칸까지 여백
        static let inset: CGFloat = 4
    }
}

// 문구
extension DimensionPicker {
    private enum Copy {
        static let label = "도면 보기 방식"
        static let selectedID = "selectedDimension"
    }
}

#Preview {
    @Previewable @State var selection = PlanDimension.twoD

    DimensionPicker(selection: $selection)
}

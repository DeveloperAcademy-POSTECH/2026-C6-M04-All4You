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

/// 2D/3D 중 하나를 고르는 막대
struct DimensionPicker: View {
    @Binding var selection: PlanDimension

    var body: some View {
        Picker(Copy.label, selection: $selection) {
            ForEach(PlanDimension.allCases, id: \.self) { dimension in
                Text(dimension.title).tag(dimension)
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.large)
        .frame(width: Layout.width)
    }
}

// 크기
extension DimensionPicker {
    private enum Layout {
        // 글자에 비해 막대가 커 보여 줄임. 메인 도면 탭과 도면 수정 화면이 이 크기를 함께 쓴다
        static let width: CGFloat = 240
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

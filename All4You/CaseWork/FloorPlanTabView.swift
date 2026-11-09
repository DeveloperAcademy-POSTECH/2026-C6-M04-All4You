// 사건 작업 메인의 도면 탭. 도면 자리, 필터 메뉴, 2D/3D 전환으로 구성된다

import SwiftUI

/// 도면을 보고 사진 표시 방식과 2D/3D를 고르는 탭
struct FloorPlanTabView: View {
    @Binding var photoFilter: PhotoFilter
    @Binding var dimension: Dimension

    /// 도면을 평면으로 볼지 입체로 볼지
    typealias Dimension = PlanDimension

    var body: some View {
        floorPlanArea
            .overlay(alignment: .topLeading) {
                PhotoFilterMenu(filter: $photoFilter)
                    .padding()
            }
            .overlay(alignment: .bottom) {
                DimensionPicker(selection: $dimension)
                    .padding()
            }
    }
}

// 서브 뷰
extension FloorPlanTabView {
    // TEMP: 도면 데이터가 생기기 전 회색 자리 — 데이터 저장 방식이 정해지면 2D 도면으로 바꿔야 함
    // TODO: 2D/3D 선택과 사진 필터에 따라 도면 표시 바꾸기 
    private var floorPlanArea: some View {
        Text(Copy.placeholder)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.quaternary)
    }
}

// 문구
extension FloorPlanTabView {
    private enum Copy {
        static let placeholder = "도면 자리"
    }
}

#Preview {
    @Previewable @State var photoFilter = PhotoFilter()
    @Previewable @State var dimension: FloorPlanTabView.Dimension = .twoD

    FloorPlanTabView(photoFilter: $photoFilter, dimension: $dimension)
}

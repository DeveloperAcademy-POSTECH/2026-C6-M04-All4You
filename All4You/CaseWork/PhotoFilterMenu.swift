// 도면 탭 왼쪽 위의 필터 버튼과 펼침 패널. 도면 위에 사진을 어떻게 보여 줄지 고른다
// 지금은 고른 값만 기억하고 도면 표시는 바뀌지 않는다

import SwiftUI

/// 필터에서 고른 값 묶음. 화면 선택 상태일 뿐 저장되는 데이터가 아니다
struct PhotoFilter {
    var isPhotoVisible = true
    var scope: Scope = .all
    var showsShootingDirection = false

    /// 도면 위에 보여 줄 사진의 범위
    enum Scope {
        case all, bookmarked
    }
}

/// "필터" 버튼을 누르면 아래로 펼쳐지는 패널.
/// 패널 머리의 스위치로 사진 표시를 켜고 끄고, 전체 사진·북마크 중 하나와 촬영 방향을 고른다
struct PhotoFilterMenu: View {
    @Binding var filter: PhotoFilter

    @State private var isOpen = false

    var body: some View {
        // TODO: 고른 값에 따라 도면 위 사진·촬영 방향 표시 바꾸기 (사진 매핑 단계)
        VStack(alignment: .leading, spacing: 0) {
            filterButton
            if isOpen {
                filterPanel
            }
        }
    }
}

// 서브 뷰
extension PhotoFilterMenu {
    /// 펼치면 ⌃, 접으면 ⌄가 보이는 필터 버튼
    private var filterButton: some View {
        Button {
            isOpen.toggle()
        } label: {
            HStack(spacing: Layout.buttonLabelSpacing) {
                Image(systemName: "line.3.horizontal.decrease")
                Text(Copy.filter)
                Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                    .font(.caption.bold())
            }
            // TEMP: 팀 공용 색이 정해지면 바꿔야 함
            .foregroundStyle(Color.primary)
        }
        .buttonStyle(.glass)
    }

    private var filterPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            panelHeader
            // 사진 표시를 끄면 도면만 보이므로 아래 항목을 고를 수 없게 한다
            Group {
                optionRow(Copy.allPhotos, isChecked: filter.scope == .all) {
                    filter.scope = .all
                }
                optionRow(Copy.bookmarked, isChecked: filter.scope == .bookmarked) {
                    filter.scope = .bookmarked
                }
                optionRow(Copy.shootingDirection, isChecked: filter.showsShootingDirection) {
                    filter.showsShootingDirection.toggle()
                }
            }
            .disabled(!filter.isPhotoVisible)
        }
        .padding(Layout.panelPadding)
        .frame(width: Layout.panelWidth)
        .glassEffect(in: .rect(cornerRadius: Layout.panelCornerRadius))
    }

    /// 작은 회색 "사진 표시" 글자와 오른쪽 스위치
    private var panelHeader: some View {
        HStack {
            Text(Copy.showPhotos)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Toggle(Copy.showPhotos, isOn: $filter.isPhotoVisible)
                .labelsHidden()
                // TEMP: 팀 공용 색이 정해지면 바꿔야 함 (Figma 기준 켜짐 색은 주황색)
                .tint(Color.blue)
                // 기본 스위치는 Figma보다 커서 그림만 줄이고, 줄인 크기만큼만 자리를 차지하게 한다
                .scaleEffect(Layout.switchScale)
                .frame(width: Layout.switchWidth, height: Layout.switchHeight)
        }
        .padding(.horizontal, Layout.rowPadding)
        .padding(.vertical, Layout.headerVerticalPadding)
    }

    /// 체크 동그라미와 글자로 된 한 줄. 고른 줄은 색이 채워지고, 고르지 않은 줄은 흐리게 보인다
    private func optionRow(_ title: String, isChecked: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Layout.rowLabelSpacing) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "checkmark.circle")
                    // TEMP: 팀 공용 색이 정해지면 바꿔야 함 (Figma 기준 체크 색은 주황색)
                    .foregroundStyle(isChecked ? Color.blue : Color.secondary)
                Text(title)
                    .foregroundStyle(isChecked ? Color.primary : Color.secondary)
                Spacer()
            }
            .padding(.horizontal, Layout.rowPadding)
            .frame(height: Layout.rowHeight)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isChecked ? .isSelected : [])
    }
}

// 크기
extension PhotoFilterMenu {
    private enum Layout {
        static let buttonLabelSpacing: CGFloat = 6
        static let panelWidth: CGFloat = 238
        static let panelPadding: CGFloat = 8
        static let panelCornerRadius: CGFloat = 34
        static let rowHeight: CGFloat = 40
        static let rowPadding: CGFloat = 8
        static let rowLabelSpacing: CGFloat = 8
        static let headerVerticalPadding: CGFloat = 4
        static let switchScale: CGFloat = 0.6
        static let switchWidth: CGFloat = 38
        static let switchHeight: CGFloat = 20
    }
}

// 문구
extension PhotoFilterMenu {
    private enum Copy {
        static let filter = "필터"
        static let showPhotos = "사진 표시"
        static let allPhotos = "전체 사진"
        static let bookmarked = "북마크"
        static let shootingDirection = "촬영 방향"
    }
}

#Preview {
    @Previewable @State var filter = PhotoFilter()

    PhotoFilterMenu(filter: $filter)
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
}

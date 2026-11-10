// 도면 탭 왼쪽 위의 필터 버튼과 펼침 패널. 도면 위에 사진을 어떻게 보여 줄지 고른다
// 북마크를 고르면 2D 도면에 북마크 사진의 촬영 위치 번호 핀(BookmarkPhotoMarkerLayer), 촬영 방향을 켜면 부채꼴이 보인다

import SwiftUI

/// 필터에서 고른 값 묶음. 화면 선택 상태일 뿐 저장되는 데이터가 아니다
struct PhotoFilter {
    var isPhotoVisible = true
    /// 전체 사진으로 바꾸면 촬영 방향도 함께 끈다
    var scope: Scope = .all {
        didSet {
            if scope == .all {
                showsDirection = false
            }
        }
    }
    /// 북마크를 골랐을 때만 켤 수 있다
    var showsDirection = false

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
    /// 버튼과 패널이 같은 유리 모양으로 이어져 바뀌게 하는 이름 공간
    @Namespace private var glassNamespace

    var body: some View {
        // 시스템 리퀴드 버튼(메뉴)처럼, 누르면 버튼이 그 자리에서 패널로 펼쳐지고 닫으면 다시 버튼으로 접힌다
        GlassEffectContainer(spacing: Layout.chipSpacing) {
            HStack(alignment: .top, spacing: Layout.chipSpacing) {
                if isOpen {
                    filterPanel
                        .glassEffectID(Layout.glassID, in: glassNamespace)
                } else {
                    filterButton
                        .glassEffectID(Layout.glassID, in: glassNamespace)
                }
                // 지금 적용 중인 필터를 버튼 옆에 칩으로 보여 준다
                // TEMP: Figma에 사진 표시를 끈 상태의 칩이 없어, 사진 표시가 켜져 있을 때만 보여 줌
                if filter.isPhotoVisible && filter.scope == .bookmarked {
                    chip(Copy.bookmarked, systemImage: "bookmark.fill") {
                        filter.scope = .all
                    }
                }
                if filter.isPhotoVisible && filter.showsDirection {
                    chip(Copy.directionChip, systemImage: "camera.viewfinder") {
                        filter.showsDirection = false
                    }
                }
            }
        }
        // 패널이 열려 있는 동안 패널 밖을 누르면 닫는다 (시스템 메뉴와 같다)
        .background(alignment: .topLeading) {
            if isOpen {
                Color.clear
                    .frame(width: Layout.dismissAreaSize, height: Layout.dismissAreaSize)
                    .contentShape(.rect)
                    .onTapGesture { setOpen(false) }
            }
        }
    }

    /// 버튼과 패널이 서로 변하도록 애니메이션과 함께 열고 닫는다
    private func setOpen(_ open: Bool) {
        withAnimation(.smooth(duration: Layout.morphDuration)) {
            isOpen = open
        }
    }
}

// 서브 뷰
extension PhotoFilterMenu {
    /// 펼치면 ⌃, 접으면 ⌄가 보이는 필터 버튼
    private var filterButton: some View {
        Button {
            setOpen(true)
        } label: {
            HStack(spacing: Layout.buttonLabelSpacing) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(AppTypography.headline)
                    .frame(width: Layout.buttonIconWidth)
                HStack(spacing: Layout.buttonTextSpacing) {
                    Text(Copy.filter)
                        .font(AppTypography.headline)
                    Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                        .font(AppTypography.subheadline.bold())
                }
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, Layout.buttonPadding)
            .frame(height: Layout.buttonHeight)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        // 크기와 간격은 직접 정하고 배경만 리퀴드 글래스를 쓴다. 누르면 유리가 반응한다
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    private var filterPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle(Copy.showPhotos, isOn: $filter.isPhotoVisible)
            // 사진 표시를 끄면 도면만 보이므로 "사진 표시" 줄만 남기고 아래 항목은 감춘다
            if filter.isPhotoVisible {
                optionRow(Copy.allPhotos, isChecked: filter.scope == .all) {
                    filter.scope = .all
                }
                optionRow(Copy.bookmarked, isChecked: filter.scope == .bookmarked) {
                    filter.scope = .bookmarked
                }
                // 촬영 방향은 북마크한 사진에만 보여 주므로 북마크를 골랐을 때만 구역이 나온다
                if filter.scope == .bookmarked {
                    Divider()
                        .padding(.horizontal, Layout.sectionHorizontalPadding)
                        .padding(.top, Layout.separatorTopPadding)
                        .padding(.bottom, Layout.separatorBottomPadding)
                    sectionTitle(Copy.direction, isOn: $filter.showsDirection)
                }
            }
        }
        .padding(.vertical, Layout.panelVerticalPadding)
        .padding(.horizontal, Layout.panelHorizontalPadding)
        .frame(width: Layout.panelWidth)
        .glassEffect(in: .rect(cornerRadius: Layout.panelCornerRadius))
    }

    /// 작은 구역 제목 글자와 오른쪽 스위치 ("사진 표시", "촬영 방향")
    private func sectionTitle(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .font(AppTypography.label.weight(.medium))
            Spacer()
            // 줄인 스위치는 누를 곳이 작아서, 자리는 그대로 두고 누르는 영역만 사방으로 넓힌다.
            // 눌림은 바깥 버튼이 받아 값을 바꾸고, 안쪽 스위치는 모양만 보여 준다
            Button {
                withAnimation {
                    isOn.wrappedValue.toggle()
                }
            } label: {
                Toggle(title, isOn: isOn)
                    .labelsHidden()
                    .tint(.brand500)
                    // 기본 스위치는 Figma보다 커서 그림만 줄이고, 줄인 크기만큼만 자리를 차지하게 한다
                    .scaleEffect(Layout.switchScale)
                    .frame(width: Layout.switchWidth, height: Layout.switchHeight)
                    .allowsHitTesting(false)
                    .padding(.horizontal, Layout.switchTapExtraWidth)
                    .padding(.vertical, Layout.switchTapExtraHeight)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, -Layout.switchTapExtraWidth)
            .padding(.vertical, -Layout.switchTapExtraHeight)
        }
        .padding(.horizontal, Layout.sectionHorizontalPadding)
        .padding(.top, Layout.sectionTopPadding)
        .padding(.bottom, Layout.sectionBottomPadding)
    }

    /// 고른 줄은 주황 체크 동그라미가 앞에 붙고, 고르지 않은 줄은 체크 없이 글자만 같은 자리에 놓인다
    private func optionRow(_ title: String, isChecked: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Layout.rowLabelSpacing) {
                ZStack {
                    if isChecked {
                        Circle()
                            .fill(.brand500)
                        Image(systemName: "checkmark")
                            // TEMP: 디자인 글자 크기에 맞는 AppTypography가 없어 가장 가까운 label을 씀
                            .font(AppTypography.label.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: Layout.checkSize, height: Layout.checkSize)
                Text(title)
                    .font(AppTypography.subheadline)
                    .padding(.leading, Layout.rowLabelLeading)
                Spacer()
            }
            .padding(.leading, Layout.rowLeadingPadding)
            .padding(.trailing, Layout.rowTrailingPadding)
            .frame(height: Layout.rowHeight)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isChecked ? .isSelected : [])
    }

    /// 글자는 배경색을 그대로 써서 다크 모드에서도 뒤집힌다
    private func chip(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Layout.chipIconSpacing) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(AppTypography.headline)
            .foregroundStyle(.background)
            .padding(.horizontal, Layout.buttonPadding)
            .frame(height: Layout.buttonHeight)
            .background(.primary, in: .capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
    }
}

// 크기
extension PhotoFilterMenu {
    private enum Layout {
        /// 버튼 ↔ 패널이 바뀌는 시간 (초)
        static let morphDuration = 0.4
        static let glassID = "filter"
        /// 패널 밖을 눌러 닫을 수 있는 영역 크기. 화면보다 크기만 하면 된다
        static let dismissAreaSize: CGFloat = 4000
        static let buttonHeight: CGFloat = 40
        static let buttonPadding: CGFloat = 8
        static let buttonIconWidth: CGFloat = 28
        static let buttonLabelSpacing: CGFloat = 8
        static let buttonTextSpacing: CGFloat = 6
        static let chipSpacing: CGFloat = 8
        static let chipIconSpacing: CGFloat = 4
        static let panelWidth: CGFloat = 238
        static let panelVerticalPadding: CGFloat = 10
        static let panelHorizontalPadding: CGFloat = 8
        static let panelCornerRadius: CGFloat = 34
        static let sectionHorizontalPadding: CGFloat = 8
        static let sectionTopPadding: CGFloat = 5
        static let sectionBottomPadding: CGFloat = 7
        static let separatorTopPadding: CGFloat = 8
        static let separatorBottomPadding: CGFloat = 9
        static let rowHeight: CGFloat = 40
        static let rowLeadingPadding: CGFloat = 6
        static let rowTrailingPadding: CGFloat = 8
        static let rowLabelSpacing: CGFloat = 8
        static let rowLabelLeading: CGFloat = 4
        static let checkSize: CGFloat = 16
        static let switchScale: CGFloat = 0.6
        static let switchWidth: CGFloat = 32
        static let switchHeight: CGFloat = 14
        /// 스위치 둘레로 누르는 영역을 넓히는 길이 (왼쪽·오른쪽 각각, 위·아래 각각)
        static let switchTapExtraWidth: CGFloat = 8
        static let switchTapExtraHeight: CGFloat = 10
    }
}

// 문구
extension PhotoFilterMenu {
    private enum Copy {
        static let filter = "필터"
        static let showPhotos = "사진 표시"
        static let allPhotos = "전체 사진"
        static let bookmarked = "북마크"
        static let direction = "촬영 방향"
        // 촬영 방향을 켰을 때 버튼 옆에 붙는 칩 글자 (패널 안 "촬영 방향"과 Figma 글자가 다르다)
        static let directionChip = "사진 방향"
    }
}

#Preview {
    @Previewable @State var filter = PhotoFilter()

    PhotoFilterMenu(filter: $filter)
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
}

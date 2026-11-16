// 사건 화면 오른쪽 위 버튼 묶음: 메모 추가·사진추가 캡슐, 수정, 내보내기.
// 사건명·차수(CaseTitleHeader), 뒤로가기·완료(Global/Toolbar.swift)와 따로 붙여 화면마다 골라 쓴다

import SwiftUI

/// 오른쪽 위 버튼 묶음을 시스템 상단 바 대신 화면 위에 직접 그린 줄. 버튼마다 할 일은 화면이 넘겨준다.
/// 시스템 상단 바의 버튼은 화면 가장자리 여백을 정할 수 없어서, 공용 상단 바(customTopBar)의 체크 버튼과 같은 자리·높이에 오도록 직접 그린다.
/// 메모 추가·사진추가는 유리 캡슐 하나를 함께 쓰고, 수정·내보내기는 각자 원이다
struct CaseActionBar: View {
    let onAddMemo: () -> Void
    let onTakePhoto: () -> Void
    let onImportPhoto: () -> Void
    let onEdit: () -> Void
    /// 넘겨주면 수정 버튼이 "평면도 수정하기"와 "사진위치 수정하기"를 고르는 메뉴가 된다
    var onEditPhotoPositions: (() -> Void)? = nil
    var isPhotoPositionEditMode = false
    let onExport: () -> Void

    var body: some View {
        HStack(spacing: BarLayout.rowSpacing) {
            HStack(spacing: 0) {
                Button(action: onAddMemo) {
                    icon("plus.bubble", width: Layout.capsuleButtonWidth)
                }
                .accessibilityLabel(Copy.addMemo)
                AddPhotoButton(onTakePhoto: onTakePhoto, onImportPhoto: onImportPhoto)
            }
            .glassEffect(.regular.interactive(), in: .capsule)
            editButton
                .glassEffect(.regular.interactive(), in: .circle)
            Button(action: onExport) {
                icon("square.and.arrow.up")
            }
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel(Copy.export)
        }
        .buttonStyle(.plain)
    }

    /// 사진위치 수정이 있는 화면은 둘 중 고르는 메뉴, 없는 화면은 바로 평면도 수정으로 간다
    @ViewBuilder
    private var editButton: some View {
        if let onEditPhotoPositions {
            Menu {
                Button(Copy.editPlan, systemImage: "square.and.pencil", action: onEdit)
                Button(
                    isPhotoPositionEditMode ? Copy.finishPhotoPositions : Copy.editPhotoPositions,
                    systemImage: isPhotoPositionEditMode ? "checkmark" : "mappin.and.ellipse",
                    action: onEditPhotoPositions
                )
            } label: {
                icon("pencil")
            }
            .accessibilityLabel(Copy.edit)
        } else {
            Button(action: onEdit) {
                icon("pencil")
            }
            .accessibilityLabel(Copy.edit)
        }
    }
}

/// 버튼 하나의 아이콘. plain 버튼은 그려진 선만 눌려서, 자리 전체를 누르는 곳으로 잡는다
private func icon(_ systemName: String, width: CGFloat = BarLayout.controlSize) -> some View {
    Image(systemName: systemName)
        .font(.system(size: BarLayout.iconSize, weight: .semibold))
        .foregroundStyle(.primary)
        .frame(width: width, height: BarLayout.controlSize)
        .contentShape(.rect)
}

/// 사진추가 아이콘을 누르면 아이콘 아래로 사진을 찍을지 불러올지 고르는 작은 창이 뜬다.
/// 기본 Menu는 버튼을 덮으며 펼쳐져서, 버튼이 그대로 보이도록 팝오버를 쓴다
private struct AddPhotoButton: View {
    let onTakePhoto: () -> Void
    let onImportPhoto: () -> Void

    @State private var isOpen = false

    var body: some View {
        Button {
            isOpen = true
        } label: {
            icon("photo.badge.plus", width: Layout.capsuleButtonWidth)
        }
        .accessibilityLabel(Copy.addPhoto)
        .popover(isPresented: $isOpen, arrowEdge: .top) {
            photoOptions
        }
    }

    /// 팝오버 안의 캡슐 버튼 두 개. 하나를 고르면 창을 닫고 화면이 넘겨준 일을 한다
    private var photoOptions: some View {
        VStack(spacing: Layout.optionSpacing) {
            optionButton(Copy.takePhoto, systemImage: "camera", action: onTakePhoto)
            optionButton(Copy.importPhoto, systemImage: "photo.on.rectangle", action: onImportPhoto)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        // Figma의 기본 버튼은 애플 기본 회색 바탕에 검은 글자라 애플 기본 색을 쓴다.
        // 누른 버튼의 주황 바탕은 창이 바로 닫혀 잠깐만 보이므로 만들지 않는다
        .tint(.primary)
        // 두 버튼을 긴 쪽 글자 폭에 맞춰 같은 너비로 만든다
        .fixedSize(horizontal: true, vertical: false)
        .padding()
        // 좁은 화면에서도 아래에서 올라오는 시트로 바뀌지 않고 작은 창으로 뜨게 한다
        .presentationCompactAdaptation(.popover)
    }

    private func optionButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button {
            isOpen = false
            action()
        } label: {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
    }
}

// 크기. CaseActionBar와 AddPhotoButton이 함께 쓰므로 파일 안 어디서나 쓸 수 있게 둔다
private enum Layout {
    /// 캡슐 안 버튼 하나의 너비. 캡슐의 둥근 끝에 아이콘이 붙지 않게 원 버튼보다 넓힌다
    static let capsuleButtonWidth: CGFloat = 52
    static let optionSpacing: CGFloat = 8
}

extension CaseActionBar {
    /// 버튼 묶음 전체의 너비 (캡슐 + 원 두 개 + 사이). 왼쪽 위 줄(CaseTitleHeader)이 이 묶음을 덮지 않게 자리를 남길 때 쓴다
    static let width = Layout.capsuleButtonWidth * 2 + BarLayout.controlSize * 2 + BarLayout.rowSpacing * 2
}

// 문구
private enum Copy {
    static let addMemo = "메모 추가"
    static let addPhoto = "사진추가"
    static let takePhoto = "사진 촬영하기"
    static let importPhoto = "사진 불러오기"
    static let edit = "수정"
    static let editPlan = "평면도 수정하기"
    static let editPhotoPositions = "사진위치 수정하기"
    static let finishPhotoPositions = "사진위치 수정 종료"
    static let export = "내보내기"
}

#Preview {
    CaseActionBar(
        onAddMemo: {},
        onTakePhoto: {},
        onImportPhoto: {},
        onEdit: {},
        onEditPhotoPositions: {},
        onExport: {}
    )
    .padding()
}

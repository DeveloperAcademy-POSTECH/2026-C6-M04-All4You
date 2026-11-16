import SwiftUI

extension View {
    /// 양쪽 버튼: 뒤로가기 + 저장. 기존 화면은 시스템 툴바를 유지
    @ViewBuilder
    func bothSidesToolbar(
        leadingTitle: String = "뒤로",
        trailingTitle: String = "완료",
        isDoneDisabled: Bool = false,
        customLayout: Bool = false,
        barTitle: String = "",
        barSubtitle: String = "",
        titleFont: Font = AppTypography.subheadlineEmphasized,
        centerAccessory: AnyView? = nil,
        trailingAccessory: AnyView? = nil,
        onBack: @escaping () -> Void,
        onDone: @escaping () -> Void
    ) -> some View {
        if customLayout {
            self.customTopBar(
                title: barTitle,
                subtitle: barSubtitle,
                leadingTitle: leadingTitle,
                trailingTitle: trailingTitle,
                isDoneDisabled: isDoneDisabled,
                titleFont: titleFont,
                centerAccessory: centerAccessory,
                trailingAccessory: trailingAccessory,
                onBack: onBack,
                onDone: onDone
            )
        } else {
            self
                .navigationBarBackButtonHidden(true)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: onBack) {
                            Label(leadingTitle, systemImage: "chevron.left")
                                .labelStyle(.iconOnly)
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: onDone) {
                            Label(trailingTitle, systemImage: "checkmark")
                                .labelStyle(.iconOnly)
                        }
                        .disabled(isDoneDisabled)
                        .buttonStyle(.borderedProminent)
                        .tint(.brand500)
                    }
                }
        }
    }

    /// 뒤로가기만 표시
    @ViewBuilder
    func backOnlyToolbar(
        title: String = "뒤로",
        customLayout: Bool = false,
        barTitle: String = "",
        barSubtitle: String = "",
        onBack: @escaping () -> Void
    ) -> some View {
        if customLayout {
            self.customTopBar(title: barTitle, subtitle: barSubtitle, leadingTitle: title, onBack: onBack)
        } else {
            self
                .navigationBarBackButtonHidden(true)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: onBack) {
                            Label(title, systemImage: "chevron.left")
                        }
                    }
                }
        }
    }

    /// 저장·완료 버튼만 표시
    @ViewBuilder
    func checkOnlyToolbar(
        title: String = "완료",
        customLayout: Bool = false,
        barTitle: String = "",
        barSubtitle: String = "",
        onDone: @escaping () -> Void
    ) -> some View {
        if customLayout {
            self.customTopBar(title: barTitle, subtitle: barSubtitle, trailingTitle: title, onDone: onDone)
        } else {
            self
                .navigationBarBackButtonHidden(true)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: onDone) {
                            Label(title, systemImage: "checkmark")
                                .labelStyle(.iconOnly)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.brand500)
                    }
                }
        }
    }

    /// 시스템 툴바의 자동 배치 없이 안전 영역에서 BarLayout.topInset 아래에 공용 바를 배치.
    /// 줄의 높이·여백은 BarLayout을 따른다. 다른 화면의 위·아래 컴포넌트도 같은 값을 써서 이 줄에 맞춘다
    private func customTopBar(
        title: String,
        subtitle: String = "",
        leadingTitle: String = "뒤로",
        trailingTitle: String = "완료",
        isDoneDisabled: Bool = false,
        titleFont: Font = AppTypography.subheadlineEmphasized,
        centerAccessory: AnyView? = nil,
        trailingAccessory: AnyView? = nil,
        onBack: (() -> Void)? = nil,
        onDone: (() -> Void)? = nil
    ) -> some View {
        self
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack(spacing: BarLayout.rowSpacing) {
                    if let onBack {
                        Button(action: onBack) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: BarLayout.iconSize, weight: .semibold))
                                .frame(width: BarLayout.controlSize, height: BarLayout.controlSize)
                                // plain 버튼은 그려진 선만 눌려서, 원 전체를 누르는 자리로 잡는다 (iPadOS 26에서 안 눌리던 문제)
                                .contentShape(.circle)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: .circle)
                        .accessibilityLabel(leadingTitle)
                    }
                    
                    if subtitle.isEmpty {
                        Text(title)
                            .font(titleFont)
                    } else {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title)
                                .font(titleFont)
                            Text(subtitle)
                                .font(AppTypography.label)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                
                    
                    Spacer()

                    // 완료 버튼 왼쪽에 화면이 끼우는 버튼 (예: 되돌리기·다시 하기)
                    if let trailingAccessory {
                        trailingAccessory
                    }

                    if let onDone {
                        Button(action: onDone) {
                            Image(systemName: "checkmark")
                                .font(.system(size: BarLayout.iconSize, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: BarLayout.controlSize, height: BarLayout.controlSize)
                                .contentShape(.circle)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.tint(.brand500).interactive(), in: .circle)
                        .disabled(isDoneDisabled)
                        .accessibilityLabel(trailingTitle)
                    }
                }
                // 바 가운데에 놓는 것(예: 2D·3D 전환 막대). 뒤로가기·제목·오른쪽 버튼과 같은 줄 가운데에 겹친다
                // 제목이나 끼운 버튼이 커도 줄 높이는 버튼 높이로 고정해, 어느 화면에서나 같은 높이에 놓이게 한다
                .frame(height: BarLayout.controlSize)
                .overlay {
                    centerAccessory
                }
                .padding(.horizontal, BarLayout.edgeInset)
                .padding(.top, BarLayout.topInset)
                .padding(.bottom, BarLayout.rowBottomInset)
            }
    }
}

#Preview {
    VStack(spacing: 0) {
        
        // 양쪽 버튼 — 라벨을 각각 변경 가능
        NavigationStack {
            Text("도면 그리기")
                .navigationTitle("양쪽 버튼")
                .navigationBarTitleDisplayMode(.inline)
                .bothSidesToolbar(
                    leadingTitle: "나가기",
                    trailingTitle: "저장",
                    customLayout: true,
                    barTitle: "스캔 미리보기",
                    barSubtitle: "청암로 77",
                    onBack: { print("나가기") },
                    onDone: { print("저장") }
                )
        }

        // 체크 없는 버전
        NavigationStack {
            Text("상세 화면")
                .navigationTitle("뒤로가기만")
                .navigationBarTitleDisplayMode(.inline)
                .backOnlyToolbar(title: "목록으로", customLayout: true, barTitle: "뒤로가기만") {
                    print("뒤로가기")
                }
        }

        // 체크만 있는 버전
        NavigationStack {
            Text("완료 화면")
                .navigationTitle("체크만")
                .navigationBarTitleDisplayMode(.inline)
                .checkOnlyToolbar(title: "확인", customLayout: true, barTitle: "체크만") {
                    print("확인")
                }
        }
    }
}

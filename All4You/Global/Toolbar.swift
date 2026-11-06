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

    /// 시스템 툴바의 자동 배치 없이 안전 영역 바로 아래에 공용 바를 배치
    private func customTopBar(
        title: String,
        subtitle: String = "",
        leadingTitle: String = "뒤로",
        trailingTitle: String = "완료",
        isDoneDisabled: Bool = false,
        onBack: (() -> Void)? = nil,
        onDone: (() -> Void)? = nil
    ) -> some View {
        self
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack(spacing: 12) {
                    if let onBack {
                        Button(action: onBack) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 17, weight: .semibold))
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: .circle)
                        .accessibilityLabel(leadingTitle)
                    }
                    
                    if subtitle.isEmpty {
                        Text(title)
                            .font(AppTypography.subheadlineEmphasized)
                    } else {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title)
                                .font(AppTypography.subheadlineEmphasized)
                            Text(subtitle)
                                .font(AppTypography.label)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                
                    
                    Spacer()

                    if let onDone {
                        Button(action: onDone) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.tint(.brand500).interactive(), in: .circle)
                        .disabled(isDoneDisabled)
                        .accessibilityLabel(trailingTitle)
                    }
                }
                .padding(.top, 16)
                .padding(.horizontal, 32)
                .padding(.bottom, 16)
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

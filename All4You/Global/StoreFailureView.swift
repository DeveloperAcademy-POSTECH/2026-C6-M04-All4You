//
//  StoreFailureView.swift
//  All4You
//

// 저장소를 열지 못했을 때 보여 주는 안내 화면. 저장소 파일은 지우지 않았다고 알리고, 오류 글을 복사하거나 백업으로 되돌릴 수 있게 한다

import SwiftUI

/// 저장소 열기 실패 안내 화면. 백업을 골라 되돌리면 `onRestore`를 불러 저장소를 다시 열게 한다
struct StoreFailureView: View {
    let error: any Error
    let onRestore: () -> Void

    @State private var backups: [StoreBackup]
    /// 확인 알림을 띄울 백업. nil이면 알림이 없다
    @State private var pendingBackup: StoreBackup?
    /// 되돌리기에 실패했을 때의 오류 글
    @State private var restoreError: String?

    init(error: any Error, onRestore: @escaping () -> Void, backups: [StoreBackup] = AppStore.backups) {
        self.error = error
        self.onRestore = onRestore
        _backups = State(initialValue: backups)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(Copy.title)
                .font(AppTypography.title1Emphasized)
            Text(Copy.message)
                .font(AppTypography.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            errorText(String(describing: error))
            if !backups.isEmpty {
                backupList
            }
            if let restoreError {
                Text(Copy.restoreFailed)
                    .font(AppTypography.subheadlineEmphasized)
                errorText(restoreError)
            }
        }
        .padding(48)
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert(Copy.confirmTitle, isPresented: isConfirmingRestore, presenting: pendingBackup) { backup in
            Button(Copy.cancel, role: .cancel) {}
            Button(Copy.restore) { restore(backup) }
        } message: { _ in
            Text(Copy.confirmMessage)
        }
    }
}

// 서브 뷰

extension StoreFailureView {
    /// 길게 눌러 복사할 수 있는 오류 글
    private func errorText(_ text: String) -> some View {
        ScrollView {
            Text(text)
                .font(AppTypography.label)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
        }
        .frame(maxHeight: 160)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    /// 만들어 둔 백업 목록. 줄마다 되돌리기 버튼이 있다
    private var backupList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(Copy.backupHeader)
                .font(AppTypography.subheadlineEmphasized)
            ForEach(backups) { backup in
                backupRow(backup)
            }
        }
    }

    private func backupRow(_ backup: StoreBackup) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(backup.createdAt.formatted(date: .abbreviated, time: .standard))
                    .font(AppTypography.headline)
                Text(ByteCountFormatter.string(fromByteCount: backup.size, countStyle: .file))
                    .font(AppTypography.label)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(Copy.restore) { pendingBackup = backup }
                .buttonStyle(.bordered)
        }
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }
}

// 동작

extension StoreFailureView {
    /// 알림의 표시 여부. 닫히면 고른 백업을 비운다
    private var isConfirmingRestore: Binding<Bool> {
        Binding(
            get: { pendingBackup != nil },
            set: { if !$0 { pendingBackup = nil } }
        )
    }

    /// 백업으로 되돌린 뒤 저장소를 다시 연다. 실패하면 오류 글을 화면에 보인다
    private func restore(_ backup: StoreBackup) {
        do {
            try AppStore.restore(backup)
            restoreError = nil
            backups = AppStore.backups
            onRestore()
        } catch {
            restoreError = String(describing: error)
        }
    }
}

// 화면 문구

private enum Copy {
    // TEMP: 안내 문구는 확정 전
    static let title = "저장된 데이터를 열지 못했어요"
    // TEMP: 안내 문구는 확정 전
    static let message = "데이터는 지우지 않았어요. 앱을 지우지 말고 개발팀에 알려 주세요."
    // TEMP: 안내 문구는 확정 전
    static let backupHeader = "백업에서 되돌리기"
    // TEMP: 안내 문구는 확정 전
    static let restore = "이 백업으로 되돌리기"
    // TEMP: 안내 문구는 확정 전
    static let cancel = "취소"
    // TEMP: 안내 문구는 확정 전
    static let confirmTitle = "이 백업으로 되돌릴까요?"
    // TEMP: 안내 문구는 확정 전
    static let confirmMessage = "지금 저장소는 따로 보관하고 이 백업으로 바꿉니다"
    // TEMP: 안내 문구는 확정 전
    static let restoreFailed = "되돌리지 못했어요"
}

#Preview {
    StoreFailureView(
        error: CocoaError(.fileReadCorruptFile),
        onRestore: {},
        backups: [
            StoreBackup(url: URL(filePath: "/preview/20261116-211249-5b8c3c74ead2"),
                        createdAt: .now, fingerprint: "5b8c3c74ead2", size: 3_400_000),
            StoreBackup(url: URL(filePath: "/preview/20261115-101500-unknown"),
                        createdAt: .now.addingTimeInterval(-86_400), fingerprint: "unknown", size: 3_100_000),
        ]
    )
}

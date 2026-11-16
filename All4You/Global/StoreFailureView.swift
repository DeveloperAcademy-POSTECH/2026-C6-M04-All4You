//
//  StoreFailureView.swift
//  All4You
//

// 저장소를 열지 못했을 때 보여 주는 안내 화면. 저장소 파일은 지우지 않았다고 알리고 오류 글을 복사할 수 있게 한다

import SwiftUI

/// 저장소 열기 실패 안내 화면. `onRestore`는 백업으로 되돌린 뒤 다시 열 때 부른다 (되돌리기는 커밋 4에서 붙인다)
struct StoreFailureView: View {
    let error: any Error
    let onRestore: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(Copy.title)
                .font(AppTypography.title1Emphasized)
            Text(Copy.message)
                .font(AppTypography.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            errorText
        }
        .padding(48)
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// 서브 뷰

extension StoreFailureView {
    /// 개발팀에 전달할 오류 글. 길게 눌러 복사할 수 있다
    private var errorText: some View {
        ScrollView {
            Text(String(describing: error))
                .font(AppTypography.label)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
        }
        .frame(maxHeight: 240)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }
}

// 화면 문구

private enum Copy {
    // TEMP: 안내 문구는 확정 전
    static let title = "저장된 데이터를 열지 못했어요"
    // TEMP: 안내 문구는 확정 전
    static let message = "데이터는 지우지 않았어요. 앱을 지우지 말고 개발팀에 알려 주세요."
}

#Preview {
    StoreFailureView(
        error: CocoaError(.fileReadCorruptFile),
        onRestore: {}
    )
}

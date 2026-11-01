//
//  Toolbar.swift
//  All4You
//
//  Created by 김가은 on 11/1/26.
//

import SwiftUI

extension View {
    // 양쪽 버튼: 뒤로가기 + 완료
    func bothSidesToolbar(
        leadingTitle: String = "뒤로",
        trailingTitle: String = "완료",
        onBack: @escaping () -> Void,
        onDone: @escaping () -> Void
    ) -> some View {
        self
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onBack) {
                        Label(leadingTitle, systemImage: "chevron.left")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: onDone) {
                        Label(trailingTitle, systemImage: "checkmark")
                    }
                }
            }
    }

    // 체크 버튼 없음: 뒤로가기만
    func backOnlyToolbar(
        title: String = "뒤로",
        onBack: @escaping () -> Void
    ) -> some View {
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

    // 뒤로가기 없음: 완료만
    func checkOnlyToolbar(
        title: String = "완료",
        onDone: @escaping () -> Void
    ) -> some View {
        self
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: onDone) {
                        Label(title, systemImage: "checkmark")
                    }
                }
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
                    onBack: { print("나가기") },
                    onDone: { print("저장") }
                )
        }

        // 체크 없는 버전
        NavigationStack {
            Text("상세 화면")
                .navigationTitle("뒤로가기만")
                .navigationBarTitleDisplayMode(.inline)
                .backOnlyToolbar(title: "목록으로") {
                    print("뒤로가기")
                }
        }

        // 체크만 있는 버전
        NavigationStack {
            Text("완료 화면")
                .navigationTitle("체크만")
                .navigationBarTitleDisplayMode(.inline)
                .checkOnlyToolbar(title: "확인") {
                    print("확인")
                }
        }
    }
}

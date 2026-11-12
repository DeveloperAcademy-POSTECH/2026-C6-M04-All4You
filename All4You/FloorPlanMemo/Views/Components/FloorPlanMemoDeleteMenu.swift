//
//  FloorPlanMemoDeleteMenu.swift
//  All4You
//
//  Created by 채유성 on 11/13/26.
//

// 메모 삭제 alert 뷰
import SwiftUI

struct FloorPlanMemoDeleteLabel: View {
    var body: some View {
        Label("메모 삭제", systemImage: "trash")
    }
}

struct FloorPlanMemoDeleteMenu: ViewModifier {
    let onDelete: () -> Void
    @State private var isDeleteConfirmationPresented = false
    
    func body(content: Content) -> some View {
        content
            .contextMenu {
                Button(role: .destructive) {
                    isDeleteConfirmationPresented = true
                } label: {
                    FloorPlanMemoDeleteLabel()
                }
            }
            .alert("메모를 삭제할까요?", isPresented: $isDeleteConfirmationPresented) {
                Button("취소", role: .cancel) {}
                Button("삭제", role: .destructive, action: onDelete)
            } message: {
                Text("삭제한 메모는 복구할 수 없어요.")
            }
    }
}

extension View {
    func memoDeleteMenu(onDelete: @escaping () -> Void) -> some View {
        modifier(FloorPlanMemoDeleteMenu(onDelete: onDelete))
    }
}

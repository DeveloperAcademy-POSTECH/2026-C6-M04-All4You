//
//  ExternalImportGlassMenu.swift
//  All4You
//
//  Created by 채유성 on 11/1/26.
//

// 외부 도면 가져오기 - 사진 찍기, 사진 선택, 파일 첨부 Glass 메뉴 컴포넌트
import SwiftUI

struct ExternalImportGlassMenu: View {
    let onCameraTap: () -> Void
    let onPhotoLibraryTap: () -> Void
    let onFileTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            menuButton("사진 찍기", icon: "camera", action: onCameraTap)
            menuButton("사진 선택", icon: "photo", action: onPhotoLibraryTap)
            Divider().padding(.leading, 44)
            menuButton("파일 첨부", icon: "folder", action: onFileTap)
        }
        .frame(width: 178)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.12), radius: 18, y: 10)
        .accessibilityElement(children: .contain)
    }

    private func menuButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .frame(height: 42)
        }
        .buttonStyle(.plain)
    }
}


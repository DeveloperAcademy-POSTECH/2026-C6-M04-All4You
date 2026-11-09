//
//  FloorPlanMemoDetailView.swift
//  All4You
//
//  Created by 채유성 on 11/09/26.
//

import SwiftUI

struct FloorPlanMemoDetailView: View {
    enum Presentation {
        case split
        case expanded
    }
    
    let memo: FloorPlanMemo
    let presentation: Presentation
    
    var body: some View {
        GeometryReader { proxy in
            switch presentation {
            case .split:
                splitLayout(width: proxy.size.width)
            case .expanded:
                expandedLayout(width: proxy.size.width)
            }
        }
        .background(Color(.systemBackground))
    }
    
    private func splitLayout(width: CGFloat) -> some View {
        let photoWidth = min(476, max(0, width - 62))
        
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                FloorPlanMemoPhotoPlaceholder()
                    .frame(width: photoWidth, height: photoWidth * 511 / 476)
                
                FloorPlanMemoDetailText(memo: memo)
                    .padding(.horizontal, 13)
            }
            .padding(.horizontal, 31)
            .padding(.top, 18)
            .frame(width: width)
        }
    }
    
    private func expandedLayout(width: CGFloat) -> some View {
        let photoWidth = min(540, max(0, (width - 88) * 540 / 1284))
        
        return ScrollView {
            HStack(alignment: .top, spacing: 24) {
                FloorPlanMemoPhotoPlaceholder()
                    .frame(width: photoWidth, height: photoWidth * 580 / 540)
                
                FloorPlanMemoDetailText(memo: memo)
                    .padding(.horizontal, 32)
                    .padding(.top, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 32)
            .padding(.top, 47)
        }
    }
}

private struct FloorPlanMemoPhotoPlaceholder: View {
    var body: some View {
        ZStack {
            Color(.secondarySystemBackground)
            Text("사진 영역")
                .font(AppTypography.headlineEmphasized)
                .foregroundStyle(.secondary)
        }
        .clipShape(RoundedRectangle(cornerRadius: 41, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("메모 사진 영역")
    }
}

private struct FloorPlanMemoDetailText: View {
    let memo: FloorPlanMemo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(memo.detailTitle)
                .font(AppTypography.title2Emphasized)
                .foregroundStyle(.primary)
            
            Text(memo.content)
                .font(AppTypography.headline)
                .foregroundStyle(.primary)
                .lineSpacing(7)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

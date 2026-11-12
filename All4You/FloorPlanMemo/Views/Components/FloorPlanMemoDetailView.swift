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
                if !memo.taggedPhotos.isEmpty {
                    photoGallery(width: photoWidth, height: photoWidth * 511 / 476)
                }
                
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
                if !memo.taggedPhotos.isEmpty {
                    photoGallery(width: photoWidth, height: photoWidth * 580 / 540)
                }
                
                FloorPlanMemoDetailText(memo: memo)
                    .padding(.horizontal, 32)
                    .padding(.top, memo.taggedPhotos.isEmpty ? 0 : 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 32)
            .padding(.top, 47)
        }
    }
    
    private func photoGallery(width: CGFloat, height: CGFloat) -> some View {
        TabView {
            ForEach(memo.taggedPhotos) { photo in
                Image(uiImage: photo.image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipped()
                    .accessibilityLabel("메모에 태그한 사진")
            }
        }
        .tabViewStyle(.page(indexDisplayMode: memo.taggedPhotos.count > 1 ? .automatic : .never))
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 41, style: .continuous))
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

//
//  PhotoDisplayOption.swift
//  All4You
//
//  Created by 채유성 on 11/8/26.
//


import SwiftUI

enum PhotoDisplayOption: String, CaseIterable, Identifiable, TitledOption {
    case hidden
    case all
    case bookmarked
    
    var id: Self { self }
    
    /// 이 표시 방식에서 도면에 보이고 함께 내보낼 사진
    func visiblePhotos(from photos: [LoadedPhoto]) -> [LoadedPhoto] {
        switch self {
        case .hidden: []
        case .all: photos
        case .bookmarked: photos.filter(\.isBookmarked)
        }
    }
    
    var title: LocalizedStringResource {
        switch self {
        case .hidden: "표시 안 함"
        case .all: "전체"
        case .bookmarked: "북마크"
        }
    }
}

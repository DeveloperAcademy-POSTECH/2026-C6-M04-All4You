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
    
    var title: LocalizedStringResource {
        switch self {
        case .hidden: "표시 안 함"
        case .all: "전체"
        case .bookmarked: "북마크"
        }
    }
}

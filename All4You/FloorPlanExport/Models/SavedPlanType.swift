//
//  SavedPlanType.swift
//  All4You
//
//  Created by 채유성 on 11/8/26.
//

import SwiftUI

enum SavedPlanType: String, CaseIterable, Identifiable, TitledOption {
    case twoD
    case threeD
    
    var id: Self { self }
    
    var title: LocalizedStringResource {
        switch self {
        case .twoD: "2D"
        case .threeD: "3D"
        }
    }
    
    var previewSymbol: String {
        switch self {
        case .twoD: "square.grid.2x2"
        case .threeD: "cube"
        }
    }
}

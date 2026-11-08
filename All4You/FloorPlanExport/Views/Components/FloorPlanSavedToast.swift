//
//  FloorPlanSavedToast.swift
//  All4You
//
//  Created by 채유성 on 11/9/26.
//

import SwiftUI

struct FloorPlanSavedToast: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 24, weight: .regular))
            
            Text("도면이 사진보관함에 저장되었어요")
                .font(.system(size: 20, weight: .medium))
                .fixedSize(horizontal: true, vertical: false)
        }
        .foregroundStyle(.white)
        .padding(16)
        .frame(height: 52)
        .background(.black, in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

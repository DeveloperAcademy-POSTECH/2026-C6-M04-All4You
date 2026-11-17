//
//  FloorPlanSavedToast.swift
//  All4You
//
//  Created by 채유성 on 11/9/26.
//

import SwiftUI

struct FloorPlanSavedToast: View {
    static let defaultMessage = "도면이 사진보관함에 저장되었어요"
    
    /// 사진을 함께 저장했을 때의 문구
    static func message(photoCount: Int) -> String {
        "도면과 사진 \(photoCount)장이 사진보관함에 저장되었어요"
    }
    
    var message = defaultMessage
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 18, weight: .regular))
            
            Text(message)
                .font(.subheadline)
                .fixedSize(horizontal: true, vertical: false)
        }
        .foregroundStyle(.white)
        .padding(16)
        .frame(height: 52)
        .background(.black, in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

//
//  ScanPreviewModePicker.swift
//  All4You
//
//  Created by 채유성 on 11/5/26.
//

// 2D·3D 도면 표현 방식 선택 Picker
import SwiftUI

enum ScanPreviewMode: String, CaseIterable {
    case twoD = "2D"
    case threeD = "3D"
}

struct ScanPreviewModePicker: View {
    @Binding var selection: ScanPreviewMode
    
    var body: some View {
        Picker("도면 보기 방식", selection: $selection) {
            ForEach(ScanPreviewMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 220)
    }
}

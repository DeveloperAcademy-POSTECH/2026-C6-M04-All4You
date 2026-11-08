//
//  FloorPlanMemoLocationPicker.swift
//  All4You
//
//  Created by 채유성 on 11/09/26.
//

import SwiftUI

struct FloorPlanMemoLocationPicker: View {
    @Binding var selection: FloorPlanMemoLocation
    
    var body: some View {
        Picker("메모 위치", selection: $selection) {
            ForEach(FloorPlanMemoLocation.allCases) { location in
                Text(location.rawValue)
                    .tag(location)
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.large)
        .frame(width: 370, height: 50)
    }
}

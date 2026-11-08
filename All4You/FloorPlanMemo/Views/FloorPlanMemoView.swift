//
//  FloorPlanMemoView.swift
//  All4You
//
//  Created by 채유성 on 11/09/26.
//

import SwiftUI

struct FloorPlanMemoView: View {
    let sections: [FloorPlanMemoSection]
    
    @State private var selectedLocation: FloorPlanMemoLocation = .all
    
    init(sections: [FloorPlanMemoSection] = .sample) {
        self.sections = sections
    }
    
    var body: some View {
        List {
            ForEach(visibleSections) { section in
                Section {
                    ForEach(section.memos) { memo in
                        FloorPlanMemoRow(memo: memo)
                            .listRowInsets(
                                EdgeInsets(top: 0, leading: 54, bottom: 0, trailing: 54)
                            )
                    }
                } header: {
                    FloorPlanMemoSectionHeader(title: section.location.rawValue)
                        .listRowInsets(
                            EdgeInsets(top: 0, leading: 54, bottom: 0, trailing: 54)
                        )
                }
            }
        }
        .listStyle(.plain)
        .listSectionSpacing(32)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FloorPlanMemoLocationPicker(selection: $selectedLocation)
                .padding(.bottom, 32)
        }
    }
    
    private var visibleSections: [FloorPlanMemoSection] {
        guard selectedLocation != .all else { return sections }
        return sections.filter { $0.location == selectedLocation }
    }
}

#Preview("도면 메모") {
    FloorPlanMemoView(sections: .sample)
}

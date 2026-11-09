//
//  All4YouApp.swift
//  All4You
//
//  Created by 채유성 on 10/14/26.
//

import SwiftUI
import SwiftData

@main
struct All4YouApp: App {
    var body: some Scene {
        WindowGroup {
            // 도면 준비 화면에서 크롭 화면으로 이동할 수 있도록 감싼다.
            NavigationStack {
                FloorPlanMethodSelectionView(
                    address: "압구정동 462-2",
                    createdAt: .now
                )
            }
        }
//        .modelContainer(for: FireCase.self)
    }
}

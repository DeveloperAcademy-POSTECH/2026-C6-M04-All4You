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
            AppLaunchView()
        }
        .modelContainer(for: FireCase.self)
    }
}

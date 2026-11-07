//
//  ContentView.swift
//  All4You
//
//  Created by 채유성 on 10/14/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        CaseListView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: FireCase.self, inMemory: true)
}

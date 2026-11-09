////
////  ContentView.swift
////  All4You
////
////  Created by 채유성 on 10/14/26.
////
//
//import SwiftUI
//import SwiftData
//
//struct ContentView: View {
//    var body: some View {
//        CaseListView()
//    }
//}
//
//#Preview {
//    ContentView()
//        .modelContainer(for: FireCase.self, inMemory: true)
//}

import SwiftUI
import SwiftData

struct ContentView: View {
    // TEMP: CaseMainView 테스트용 — 테스트 끝나면 CaseListView()로 되돌리기
    @State private var photoStore = PhotoStore()

    var body: some View {
        CaseMainView(
            planData: DummyFloorPlan.planData,
            photoStore: photoStore,
            onBack: {},
            onEdit: {}
        )
    }
}

#Preview {
    ContentView()
        .modelContainer(for: FireCase.self, inMemory: true)
}

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
    /// 저장소를 연 결과. 실패하면 안내 화면을 보여 주고, 백업으로 되돌리면 다시 연다
    @State private var store = AppStore.openResult()

    var body: some Scene {
        WindowGroup {
            switch store {
            case .success(let container):
                AppLaunchView()
                    .modelContainer(container)
            case .failure(let error):
                StoreFailureView(error: error, onRestore: { store = AppStore.openResult() })
            }
        }
    }
}

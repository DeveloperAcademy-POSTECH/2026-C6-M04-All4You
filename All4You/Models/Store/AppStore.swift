//
//  AppStore.swift
//  All4You
//

// 앱의 SwiftData 저장소를 만드는 곳. 모델 목록과 저장소 위치는 여기에만 둔다

import Foundation
import SwiftData

enum AppStore {
    /// 저장하는 모델 전부. 모델을 새로 만들면 여기에 더한다
    static let schema = Schema([
        FireCase.self, CaseFolder.self, InvestigationSession.self,
        EvidencePhoto.self, Memo.self, FloorPlan.self,
    ])

    /// 이름·위치를 주지 않아 지금까지 쓰던 기본 저장소(Application Support/default.store)를 그대로 쓴다
    static let configuration = ModelConfiguration(schema: schema)

    static var storeURL: URL { configuration.url }

    /// Xcode 미리보기로 떴는지. 미리보기는 실제 저장소·기록·백업을 건드리지 않는다
    static var isRunningForPreviews: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    /// 저장소를 연다. 실패해도 저장소 파일은 건드리지 않고 오류만 돌려준다. 미리보기가 아니면 결과를 기록에 남긴다
    static func openResult() -> Result<ModelContainer, any Error> {
        if isRunningForPreviews {
            return Result {
                try ModelContainer(
                    for: schema,
                    configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
                )
            }
        }

        // 열면 파일이 생기므로 열기 전에 상태를 구해 둔다
        let fileSummary = storeFileSummary()
        let result = Result { try ModelContainer(for: schema, configurations: [configuration]) }
        let prefix = "build=\(buildSummary()) store=\(fileSummary)"
        switch result {
        case .success(let container):
            record("\(prefix) 결과=열림 \(rowCountSummary(in: container))")
        case .failure(let error):
            record("\(prefix) 결과=실패 \(String(describing: error))")
        }
        return result
    }
}

//
//  AppStore+Log.swift
//  All4You
//

// 실행할 때마다 저장소 상태를 파일(store-log.txt)과 콘솔에 남긴다. 사고가 난 뒤 원인을 찾는 데 쓴다

import Foundation
import OSLog
import SwiftData

extension AppStore {
    private static let logger = Logger(subsystem: "All4You", category: "Store")

    /// 기록 파일에 남기는 최대 줄 수. 넘으면 앞에서부터 버린다
    private static let maxLogLines = 200

    /// 저장소 파일이 들어 있는 폴더 (Application Support)
    static var supportDirectory: URL {
        storeURL.deletingLastPathComponent()
    }

    private static var logURL: URL {
        supportDirectory.appendingPathComponent("store-log.txt")
    }

    /// 한 줄을 기록 파일 끝에 더하고 콘솔에도 찍는다. 파일 쓰기에 실패해도 앱은 멈추지 않는다
    static func record(_ text: String) {
        let line = "\(timestamp()) \(text)"
        logger.notice("\(line, privacy: .public)")

        let old = (try? String(contentsOf: logURL, encoding: .utf8)) ?? ""
        let lines = old.split(separator: "\n").map(String.init) + [line]
        let kept = lines.suffix(maxLogLines).joined(separator: "\n") + "\n"
        try? FileManager.default.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
        try? kept.write(to: logURL, atomically: true, encoding: .utf8)
    }

    /// 저장소 파일이 있는지, 만든 날, 크기(-wal 포함). 열면 파일이 생기므로 열기 전에 구해 둔다
    static func storeFileSummary() -> String {
        let manager = FileManager.default
        guard manager.fileExists(atPath: storeURL.path) else { return "없음" }

        let attributes = try? manager.attributesOfItem(atPath: storeURL.path)
        let createdAt = attributes?[.creationDate] as? Date
        let walURL = URL(fileURLWithPath: storeURL.path + "-wal")
        let walAttributes = try? manager.attributesOfItem(atPath: walURL.path)
        let size = (attributes?[.size] as? Int64 ?? 0) + (walAttributes?[.size] as? Int64 ?? 0)

        let sizeText = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        let createdText = createdAt.map { timestamp($0) } ?? "만든 날 모름"
        return "있음(만든 날 \(createdText), \(sizeText))"
    }

    /// 모델별 저장된 개수. 하나라도 세지 못하면 "개수 모름"
    static func rowCountSummary(in container: ModelContainer) -> String {
        let context = ModelContext(container)
        do {
            let cases = try context.fetchCount(FetchDescriptor<FireCase>())
            let floorPlans = try context.fetchCount(FetchDescriptor<FloorPlan>())
            let sessions = try context.fetchCount(FetchDescriptor<InvestigationSession>())
            let photos = try context.fetchCount(FetchDescriptor<EvidencePhoto>())
            let memos = try context.fetchCount(FetchDescriptor<Memo>())
            let folders = try context.fetchCount(FetchDescriptor<CaseFolder>())
            return "사건=\(cases) 평면도=\(floorPlans) 차수=\(sessions) 사진=\(photos) 메모=\(memos) 목록=\(folders)"
        } catch {
            return "개수 모름"
        }
    }

    /// 지금 빌드의 버전 글 ("1.0(1)")
    static func buildSummary() -> String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version)(\(build))"
    }

    private static func timestamp(_ date: Date = .now) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = .current
        return formatter.string(from: date)
    }
}

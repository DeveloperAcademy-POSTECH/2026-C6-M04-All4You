//
//  AppStore+Backup.swift
//  All4You
//

// 모델 구조(스키마 지문)가 바뀐 빌드를 처음 열 때, 저장소를 열기 전에 통째로 복사해 둔다

import CryptoKit
import Foundation
import SwiftData

extension AppStore {
    /// 남겨 둘 백업 수. 새 빌드 → 옛 브랜치 → 새 빌드로 오가도 온전한 백업이 덮어써지지 않게 2개
    private static let maxBackupCount = 2

    /// 저장소 파일 이름의 앞부분. 이 이름으로 시작하는 파일(-wal, -shm 포함)을 모두 복사한다
    private static let storeFilePrefix = "default.store"

    /// 저장소 옆에 SwiftData가 만드는 폴더 (externalStorage로 둔 사진 파일이 여기에 있다)
    private static let storeSupportFolderName = ".default_SUPPORT"

    private static var backupsDirectory: URL {
        supportDirectory.appendingPathComponent("StoreBackups")
    }

    /// 이 저장소를 마지막으로 연 빌드의 스키마 지문을 적어 두는 파일
    private static var schemaFileURL: URL {
        supportDirectory.appendingPathComponent("store-schema.txt")
    }

    /// 지금 빌드의 모델 구조를 한 줄 값으로 줄인 것. 모델에 칸을 더하거나 빼거나 타입을 바꾸면 달라진다
    /// 한계: JSON으로 넣는 값(PlanData)의 구조 변화와 enum의 case 추가는 잡지 못한다
    static var schemaFingerprint: String {
        let lines = schema.entities.sorted { $0.name < $1.name }.map { entity in
            let attributes = entity.attributes.sorted { $0.name < $1.name }
                .map { "\($0.name):\(String(describing: $0.valueType)):\($0.isOptional)" }
            let relationships = entity.relationships.sorted { $0.name < $1.name }
                .map { "\($0.name)->\($0.destination):\($0.isToOneRelationship)" }
            return ([entity.name] + attributes + relationships).joined(separator: "|")
        }
        let digest = SHA256.hash(data: Data(lines.joined(separator: "\n").utf8))
        return digest.prefix(6).map { String(format: "%02x", $0) }.joined()
    }

    /// 저장소를 마지막으로 연 빌드와 지문이 다르면 열기 전에 백업한다. 기록에 넣을 요약 글을 돌려준다
    /// 반드시 ModelContainer를 만들기 전에 불러야 한다. 열린 연결이 없어야 -wal까지 그대로 복사해도 온전하다
    static func backUpIfSchemaChanged() -> String {
        let manager = FileManager.default
        guard manager.fileExists(atPath: storeURL.path) else { return "백업=없음(새 저장소)" }

        let savedFingerprint = (try? String(contentsOf: schemaFileURL, encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard savedFingerprint != schemaFingerprint else { return "백업=없음" }

        let folder = backupsDirectory.appendingPathComponent(
            "\(backupTimestamp())-\(savedFingerprint ?? "unknown")"
        )
        let start = ContinuousClock.now
        do {
            try copyStoreFiles(to: folder)
        } catch {
            // 백업에 실패해도 저장소는 그대로 연다 (사용자 결정 2026-11-16)
            try? manager.removeItem(at: folder)
            return "백업=실패 \(error)"
        }
        pruneBackups()
        return "백업=\(folder.lastPathComponent) (\(seconds(since: start)))"
    }

    /// 지금 빌드의 지문을 적어 둔다. 열기에 성공했을 때만 부른다
    static func saveSchemaFingerprint() {
        try? schemaFingerprint.write(to: schemaFileURL, atomically: true, encoding: .utf8)
    }
}

// 파일 복사와 정리

extension AppStore {
    /// 저장소 파일과 .default_SUPPORT 폴더를 folder 안으로 복사한다
    private static func copyStoreFiles(to folder: URL) throws {
        let manager = FileManager.default
        try manager.createDirectory(at: folder, withIntermediateDirectories: true)
        let names = try manager.contentsOfDirectory(atPath: supportDirectory.path)
            .filter { $0.hasPrefix(storeFilePrefix) || $0 == storeSupportFolderName }
        for name in names {
            try manager.copyItem(
                at: supportDirectory.appendingPathComponent(name),
                to: folder.appendingPathComponent(name)
            )
        }
    }

    /// 이름이 -replaced로 끝나지 않는 백업 폴더 중 오래된 것을 지운다 (이름이 시각이라 이름순 = 오래된 순)
    private static func pruneBackups() {
        let manager = FileManager.default
        let names = (try? manager.contentsOfDirectory(atPath: backupsDirectory.path)) ?? []
        let backups = names.filter { !$0.hasSuffix("-replaced") }.sorted()
        for name in backups.dropLast(maxBackupCount) {
            try? manager.removeItem(at: backupsDirectory.appendingPathComponent(name))
        }
    }

    private static func backupTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: .now)
    }

    private static func seconds(since start: ContinuousClock.Instant) -> String {
        let parts = (ContinuousClock.now - start).components
        let value = Double(parts.seconds) + Double(parts.attoseconds) / 1e18
        return String(format: "%.3f초", value)
    }
}

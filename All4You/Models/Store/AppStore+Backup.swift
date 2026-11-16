//
//  AppStore+Backup.swift
//  All4You
//

// 모델 구조(스키마 지문)가 바뀐 빌드를 처음 열 때, 저장소를 열기 전에 통째로 복사해 둔다

import CryptoKit
import Foundation
import SwiftData

/// 열기 전에 만들어 둔 저장소 백업 하나. 안내 화면의 되돌리기 목록에 쓴다
struct StoreBackup: Identifiable {
    /// 백업 폴더 위치 (이름은 "yyyyMMdd-HHmmss-<그때 지문>")
    let url: URL
    let createdAt: Date
    /// 이 백업을 만들기 직전에 저장소를 연 빌드의 스키마 지문. 모르면 "unknown"
    let fingerprint: String
    /// 폴더 안 파일 크기의 합 (바이트)
    let size: Int64

    var id: URL { url }
}

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
        backupDateFormatter.string(from: .now)
    }

    /// 백업 폴더 이름 앞부분의 시각 모양
    private static var backupDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }

    private static func seconds(since start: ContinuousClock.Instant) -> String {
        let parts = (ContinuousClock.now - start).components
        let value = Double(parts.seconds) + Double(parts.attoseconds) / 1e18
        return String(format: "%.3f초", value)
    }
}

// 되돌리기

extension AppStore {
    /// 되돌리기 전에 옆으로 옮겨 둔 저장소는 최근 1개만 남긴다
    private static let maxReplacedCount = 1

    /// 만들어 둔 백업 목록 (최신순). -replaced 폴더는 뺀다
    static var backups: [StoreBackup] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: backupsDirectory.path)) ?? []
        return names.filter { !$0.hasSuffix("-replaced") }.sorted(by: >).compactMap(backup(named:))
    }

    /// 지금 저장소를 StoreBackups/<지금 시각>-replaced/ 로 옮기고(지우지 않는다) 백업 내용을 그 자리에 복사한다
    /// 저장소가 열려 있지 않을 때(안내 화면)만 부른다. 복사에 실패하면 옮긴 것을 제자리로 돌려놓고 오류를 던진다
    static func restore(_ backup: StoreBackup) throws {
        // 미리보기 화면에서는 실제 저장소를 건드리지 않는다
        guard !isRunningForPreviews else { throw CocoaError(.featureUnsupported) }

        let manager = FileManager.default
        let replacedFolder = backupsDirectory.appendingPathComponent("\(backupTimestamp())-replaced")
        try manager.createDirectory(at: replacedFolder, withIntermediateDirectories: true)

        // 1. 지금 저장소를 옆으로 옮긴다
        let movedNames = try storeItemNames(in: supportDirectory)
        for name in movedNames {
            try manager.moveItem(at: supportDirectory.appendingPathComponent(name),
                                 to: replacedFolder.appendingPathComponent(name))
        }

        // 2. 백업 내용을 복사한다. 실패하면 복사하다 만 것을 옆으로 치우고 옮겨 둔 저장소를 돌려놓는다
        do {
            for name in try storeItemNames(in: backup.url) {
                try manager.copyItem(at: backup.url.appendingPathComponent(name),
                                     to: supportDirectory.appendingPathComponent(name))
            }
        } catch {
            undoRestore(movedNames: movedNames, replacedFolder: replacedFolder)
            throw error
        }

        // 3. 되돌린 직후 같은 내용을 또 백업하지 않도록 지금 빌드의 지문을 적는다
        try? schemaFingerprint.write(to: schemaFileURL, atomically: true, encoding: .utf8)
        pruneReplacedFolders()
        record("되돌림 \(backup.url.lastPathComponent)")
    }
}

// 되돌리기 도우미

extension AppStore {
    /// 폴더 안에서 저장소에 속한 이름들 (default.store*, .default_SUPPORT)
    private static func storeItemNames(in folder: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: folder.path)
            .filter { $0.hasPrefix(storeFilePrefix) || $0 == storeSupportFolderName }
    }

    /// 복사에 실패했을 때: 복사하다 만 파일은 지우지 않고 partial 폴더로 옮기고, 옮겨 둔 저장소를 제자리로 돌린다
    private static func undoRestore(movedNames: [String], replacedFolder: URL) {
        let manager = FileManager.default
        let partialFolder = replacedFolder.appendingPathComponent("partial-restore")
        try? manager.createDirectory(at: partialFolder, withIntermediateDirectories: true)
        for name in movedNames {
            let target = supportDirectory.appendingPathComponent(name)
            if manager.fileExists(atPath: target.path) {
                try? manager.moveItem(at: target, to: partialFolder.appendingPathComponent(name))
            }
            try? manager.moveItem(at: replacedFolder.appendingPathComponent(name), to: target)
        }
    }

    /// -replaced 폴더 중 오래된 것을 지운다 (옮겨 둔 저장소는 최근 1개만 남긴다)
    private static func pruneReplacedFolders() {
        let manager = FileManager.default
        let names = (try? manager.contentsOfDirectory(atPath: backupsDirectory.path)) ?? []
        let replaced = names.filter { $0.hasSuffix("-replaced") }.sorted()
        for name in replaced.dropLast(maxReplacedCount) {
            try? manager.removeItem(at: backupsDirectory.appendingPathComponent(name))
        }
    }

    /// 폴더 이름("yyyyMMdd-HHmmss-<지문>")에서 만든 시각과 지문을 읽어 백업 하나로 만든다. 이름 모양이 다르면 nil
    private static func backup(named name: String) -> StoreBackup? {
        let dateLength = "yyyyMMdd-HHmmss".count
        guard name.count > dateLength + 1,
              let createdAt = backupDateFormatter.date(from: String(name.prefix(dateLength))) else { return nil }
        let url = backupsDirectory.appendingPathComponent(name)
        return StoreBackup(url: url,
                           createdAt: createdAt,
                           fingerprint: String(name.dropFirst(dateLength + 1)),
                           size: folderSize(url))
    }

    private static func folderSize(_ folder: URL) -> Int64 {
        let files = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: [.fileSizeKey])
        var total: Int64 = 0
        while let url = files?.nextObject() as? URL {
            total += Int64((try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
        }
        return total
    }
}

// 읽지 못한 도면 보관

extension AppStore {
    private static var unreadablePlansDirectory: URL {
        supportDirectory.appendingPathComponent("UnreadablePlans")
    }

    /// 읽지 못한 도면 JSON을 UnreadablePlans/<사건 id>-<시각>.json 으로 남기고 기록한다.
    /// 쓰기에 실패하면 기록만 남기고 넘어간다 (사용자가 이미 새로 만들기를 골랐다)
    static func keepUnreadablePlan(_ data: Data, caseID: UUID) {
        let name = "\(caseID.uuidString)-\(backupTimestamp()).json"
        do {
            try FileManager.default.createDirectory(at: unreadablePlansDirectory, withIntermediateDirectories: true)
            try data.write(to: unreadablePlansDirectory.appendingPathComponent(name), options: .atomic)
            record("읽지 못한 도면 보관 \(name)")
        } catch {
            record("읽지 못한 도면 보관 실패 \(name) \(error)")
        }
    }
}

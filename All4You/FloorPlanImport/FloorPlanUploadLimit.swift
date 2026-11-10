import Foundation

@MainActor
enum FloorPlanUploadLimit {
    private static let dailyLimit = 3
    private static let storageKey = "floorPlanDailyUploads"

    static func recordUpload(now: Date = .now, defaults: UserDefaults = .standard) throws {
        let usage = defaults.dictionary(forKey: storageKey)
        let count: Int
        if let lastUpload = usage?["date"] as? Date,
           Calendar.current.isDate(lastUpload, inSameDayAs: now) {
            count = usage?["count"] as? Int ?? 0
        } else {
            count = 0
        }

        guard count < dailyLimit else { throw LimitReached() }
        defaults.set(["date": now, "count": count + 1], forKey: storageKey)
    }

    private struct LimitReached: LocalizedError {
        var errorDescription: String? {
            "오늘 도면 업로드 3회를 모두 사용했어요. 내일 다시 이용해 주세요."
        }
    }
}

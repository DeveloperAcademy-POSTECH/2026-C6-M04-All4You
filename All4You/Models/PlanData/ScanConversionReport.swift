// 공간 스캔을 도면으로 바꾼 결과를 원본과 맞춰 본 기록. 저장하지 않는 값이고, 변환이 도면과 함께 돌려준다
// 원본의 벽·문·창문·개구부·가구가 도면에 모두 나오는지, 나오지 못했다면 무엇이 왜 빠졌는지 남긴다

import Foundation

struct ScanConversionReport: Equatable {
    /// 대조하는 요소 종류
    enum Kind: CaseIterable {
        case wall, door, window, opening, furniture

        /// 안내 문구에 쓰는 이름
        var title: String {
            switch self {
            case .wall: "벽"
            case .door: "문"
            case .window: "창문"
            case .opening: "개구부"
            case .furniture: "가구"
            }
        }
    }

    /// 도면에 나오지 못한 이유
    enum Reason: Equatable {
        /// 10cm보다 짧아 버림
        case tooShort
        /// 같은 벽을 두 번 스캔해 남은 벽 하나로 합쳐짐 (벽이 사라진 것이 아님)
        case overlapped
        /// 양 끝이 한 꼭짓점으로 합쳐져 벽으로 남을 수 없음
        case absorbed
        /// 붙일 벽을 찾지 못함
        case noWallToAttach
        /// 위치·크기에 NaN·무한대가 들어 있어 변환에서 뺌
        case invalidNumber
        /// 방을 나누며 꼭짓점이 합쳐져 벽과 함께 사라짐
        case mergedWhileSplitting

        var description: String {
            switch self {
            case .tooShort: "너무 짧음"
            case .overlapped: "겹쳐서 하나로 합쳐짐"
            case .absorbed: "끝점이 한 점으로 합쳐짐"
            case .noWallToAttach: "붙일 벽 없음"
            case .invalidNumber: "비정상 숫자"
            case .mergedWhileSplitting: "방 나누기에서 합쳐짐"
            }
        }
    }

    /// 도면에 나오지 못한 요소 하나
    struct Omission: Equatable {
        let kind: Kind
        /// RoomPlan 원본의 식별자. 가구는 식별자를 담지 않아 nil
        let sourceId: UUID?
        let reason: Reason

        /// 사용자가 직접 그려 넣어야 할 만한 손실인지. 같은 벽이 겹쳐 합쳐지거나 아주 짧은 벽이 사라진 것은 손실로 보지 않는다
        var isLoss: Bool {
            kind == .wall ? reason == .invalidNumber : true
        }
    }

    /// 원본 면·물체 개수
    var sourceCounts: [Kind: Int] = [:]
    /// 도면에 나온 개수
    var planCounts: [Kind: Int] = [:]
    var omissions: [Omission] = []
    /// 벽 끝점이 원본에서 움직인 가장 먼 거리 (m). 4° 직각 맞춤·바깥 밀기·모서리 잇기·꼭짓점 합치기를 모두 합친 값
    var maxWallShift = 0.0

    /// 사용자에게 알릴 손실만
    var losses: [Omission] { omissions.filter(\.isLoss) }

    /// 미리보기에 보일 안내 문구. 손실이 없으면 nil
    // TEMP: Figma에 없는 문구
    var lossMessage: String? {
        let parts = Kind.allCases.compactMap { kind -> String? in
            let count = losses.filter { $0.kind == kind }.count
            return count > 0 ? "\(kind.title) \(count)개" : nil
        }
        return parts.isEmpty ? nil : "\(parts.joined(separator: ", "))를 도면에 옮기지 못했어요"
    }

    /// 전체 기록 (디버그 로그용)
    var logText: String {
        var lines = ["스캔 변환 대조 — 벽 끝점이 움직인 최대 거리 \(String(format: "%.3f", maxWallShift))m"]
        for kind in Kind.allCases {
            lines.append("  \(kind.title): 원본 \(sourceCounts[kind, default: 0]) → 도면 \(planCounts[kind, default: 0])")
        }
        for omission in omissions {
            lines.append("  빠짐 \(omission.kind.title) \(omission.sourceId?.uuidString ?? "-") — \(omission.reason.description)\(omission.isLoss ? " (손실)" : "")")
        }
        return lines.joined(separator: "\n")
    }

    mutating func omit(_ kind: Kind, _ sourceId: UUID?, _ reason: Reason) {
        omissions.append(Omission(kind: kind, sourceId: sourceId, reason: reason))
    }
}

extension ScanConversionReport.Kind {
    /// 스캔 면 종류에 맞는 대조 종류. 바닥은 대조하지 않는다
    init?(_ kind: ScanSurface.Kind) {
        switch kind {
        case .wall: self = .wall
        case .door: self = .door
        case .window: self = .window
        case .opening: self = .opening
        case .floor: return nil
        }
    }
}

extension ScanSurface {
    /// 위치·크기가 모두 유한한 숫자인지. NaN·무한대가 하나라도 있으면 그 면 때문에 도면 전체 좌표가 망가진다
    var isFinite: Bool {
        center.isFinite && widthAxis.isFinite && width.isFinite && height.isFinite && corners.allSatisfy(\.isFinite)
    }
}

extension ScanObject {
    var isFinite: Bool {
        center.isFinite && widthAxis.isFinite && width.isFinite && height.isFinite && depth.isFinite
    }
}

private extension SIMD2<Double> {
    var isFinite: Bool { x.isFinite && y.isFinite }
}

private extension SIMD3<Double> {
    var isFinite: Bool { x.isFinite && y.isFinite && z.isFinite }
}

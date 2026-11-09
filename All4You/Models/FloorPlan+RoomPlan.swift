// 공간 스캔(RoomPlan) 원본을 평면도의 roomPlanData에 JSON으로 담고 읽기
// Apple이 Codable로 주는 CapturedStructure·CapturedRoom을 그대로 저장한다

import Foundation
import RoomPlan

/// 스캔 원본 하나
struct RoomPlanOriginal: Codable {
    /// 여러 구간을 합친 구조. 구간이 2개 이상일 때만 있다
    let structure: CapturedStructure?
    /// 구간별 결과
    let rooms: [CapturedRoom]
}

extension RoomPlanOriginal {
    func encoded() throws -> Data {
        try Self.encoder.encode(self)
    }

    static func decode(_ data: Data) throws -> RoomPlanOriginal {
        try decoder.decode(RoomPlanOriginal.self, from: data)
    }

    // 스캔 값에 섞여 나올 수 있는 무한대·NaN도 잃지 않도록 문자열로 저장한다 (RoomPlanSegmentService와 같은 방식)
    private static let infinity = "Infinity"
    private static let negativeInfinity = "-Infinity"
    private static let notANumber = "NaN"

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.nonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: infinity, negativeInfinity: negativeInfinity, nan: notANumber)
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: infinity, negativeInfinity: negativeInfinity, nan: notANumber)
        return decoder
    }
}

extension FloorPlan {
    /// 저장된 스캔 원본을 읽는다. 없거나 못 읽으면 nil
    func loadRoomPlan() -> RoomPlanOriginal? {
        roomPlanData.flatMap { try? RoomPlanOriginal.decode($0) }
    }
}

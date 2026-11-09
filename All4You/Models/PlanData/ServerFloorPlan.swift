// 도면 변환 서버가 돌려주는 도면 JSON(format "floorplan_annotation_proposal")을 읽는 그릇
// 좌표는 픽셀, 원점 = 사진 왼쪽 위, +x 오른쪽, +y 아래. 앱 도면(PlanData)으로 바꿀 때 쓰는 칸만 읽는다

import Foundation

/// 변환 서버의 도면 하나 (픽셀 단위)
struct ServerFloorPlan: Decodable {
    let format: String
    let vertices: [Vertex]
    let walls: [Wall]
    let openings: [Opening]
    let rooms: [Room]
    /// 가구. 서버가 찾지 못하면 칸이 없을 수 있다
    let furniture: [Furniture]?
    /// 실제 길이와의 비율. 서버가 모르면 비어 있다
    let calibration: Calibration?

    struct Vertex: Decodable {
        let id: String
        let x: Double
        let y: Double
    }

    struct Wall: Decodable {
        let id: String
        let startVertex: String
        let endVertex: String
    }

    /// 문·창문. 벽 시작점에서 문·창문 시작까지의 거리(offset)와 폭으로 위치를 준다
    struct Opening: Decodable {
        let id: String
        let kind: String
        let wallId: String
        let offset: Double
        let width: Double
    }

    struct Room: Decodable {
        let id: String
        let name: String?
        let boundary: [RoomEdge]
        /// 이름을 보여 줄 자리 [x, y]
        let labelPosition: [Double]?
    }

    struct RoomEdge: Decodable {
        let wallId: String
        let forward: Bool
    }

    /// 가구 하나. 위치와 크기는 돌리지 않은 상자 [왼쪽, 위, 오른쪽, 아래]
    struct Furniture: Decodable {
        let id: String
        let label: String?
        let bbox: [Double]
    }

    struct Calibration: Decodable {
        let metersPerPixel: Double?
    }
}

extension ServerFloorPlan {
    /// 좌표가 들어 있는 형식 이름. 픽셀 예측 미리보기("floorplan_segmentation_preview")는 꼭짓점·벽이 없어 도면으로 바꿀 수 없다
    static let annotationFormat = "floorplan_annotation_proposal"

    /// 서버 JSON을 읽는다. 좌표가 없는 형식이면 에러
    static func decode(_ data: Data) throws -> ServerFloorPlan {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let header = try decoder.decode(Header.self, from: data)
        guard header.format == annotationFormat else {
            throw FormatError(format: header.format)
        }
        return try decoder.decode(ServerFloorPlan.self, from: data)
    }

    /// 형식 이름만 먼저 읽기 위한 그릇
    private struct Header: Decodable {
        let format: String
    }

    struct FormatError: LocalizedError {
        let format: String
        var errorDescription: String? { "도면 좌표가 없는 형식(\(format))이라 도면으로 바꿀 수 없습니다." }
    }
}

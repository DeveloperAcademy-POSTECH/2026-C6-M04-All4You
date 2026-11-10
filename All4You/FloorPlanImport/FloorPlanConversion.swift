import Foundation
import UIKit

struct FloorPlanConversion {
    let preview: UIImage
    let png: Data
    let json: Data
    let isSegmentationPreview: Bool

    static func request(_ image: UIImage) async throws -> Self {
        // 실기기에서도 접근할 수 있는 운영 서버를 기본값으로 사용한다.
        let defaultBaseURL = "https://ganni-c6.asherlab.dev"
        let configuredBaseURL = Bundle.main.object(forInfoDictionaryKey: "FloorPlanAPIURL") as? String
        #if DEBUG
        // 로컬 테스트에서는 Xcode 환경 변수로 서버를 바꿀 수 있다.
        let baseURL = ProcessInfo.processInfo.environment["FLOORPLAN_API_URL"]
            ?? configuredBaseURL ?? defaultBaseURL
        #else
        let baseURL = configuredBaseURL ?? defaultBaseURL
        #endif
        guard let url = URL(string: baseURL), url.host != nil else {
            throw ConversionError(message: "도면 변환 서버 주소를 설정해 주세요.")
        }
        guard let photo = image.jpegData(compressionQuality: 0.9) else {
            throw ConversionError(message: "스캔 사진을 JPEG로 변환하지 못했습니다.")
        }
        guard photo.count <= 10 * 1024 * 1024 else {
            throw ConversionError(message: "사진 용량은 10 MiB 이하여야 합니다.")
        }

        let boundary = UUID().uuidString
        // 서버는 기하 검증에 실패하면 한 번 보정할 수 있다.
        var request = URLRequest(url: url.appending(path: "v1/floor-plans"), timeoutInterval: 95)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"image\"; filename=\"scan.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n".utf8)
        body.append(photo)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))

        try Task.checkCancellation()
        try FloorPlanUploadLimit.recordUpload()
        let (data, response) = try await URLSession.shared.upload(for: request, from: body)
        let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let response = response as? HTTPURLResponse else {
            throw ConversionError(message: "도면 변환 서버의 응답을 확인할 수 없습니다.")
        }
        guard response.statusCode == 200 else {
            let detail = payload?["detail"] as? String
            throw ConversionError(message: detail ?? "도면 변환에 실패했습니다 (\(response.statusCode)).")
        }
        guard let encoded = payload?["png_base64"] as? String,
              let png = Data(base64Encoded: encoded),
              let preview = UIImage(data: png),
              let plan = payload?["plan"] as? [String: Any] else {
            throw ConversionError(message: "응답에서 도면 PNG와 좌표 JSON을 읽지 못했습니다.")
        }
        let json = try JSONSerialization.data(withJSONObject: plan, options: [.prettyPrinted, .sortedKeys])
        return Self(
            preview: preview,
            png: png,
            json: json,
            isSegmentationPreview: (plan["format"] as? String) == "floorplan_segmentation_preview"
        )
    }

    func save() throws {
        let files = FileManager.default
        let support = try files.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                    appropriateFor: nil, create: true)
        let root = support.appending(path: "ImportedFloorPlans", directoryHint: .isDirectory)
        try files.createDirectory(at: root, withIntermediateDirectories: true)
        let id = UUID().uuidString
        let staging = root.appending(path: ".\(id)", directoryHint: .isDirectory)
        try files.createDirectory(at: staging, withIntermediateDirectories: false)
        defer { try? files.removeItem(at: staging) }

        try png.write(to: staging.appending(path: "floor-plan.png"))
        try json.write(to: staging.appending(path: "floor-plan.json"))
        try files.moveItem(at: staging, to: root.appending(path: id, directoryHint: .isDirectory))
    }

    private struct ConversionError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }
}

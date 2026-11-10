// 공간 스캔 중 찍은 사진을 사건의 사진으로 저장하는 규칙.
// 카메라 자세를 도면 위치로 바꿔, 그 자리를 품은 장소에 바로 놓는다

import Foundation
import OSLog

extension FireCase {
    /// 스캔 사진을 사건 사진(EvidencePhoto)으로 더한다. 가장 최근 조사 차수에 들어간다.
    /// 도면에 스캔 변환이 없거나, 추적이 불안정했거나, 방 밖에서 찍힌 사진은 위치 미지정으로 들어간다.
    /// 같은 id가 이미 있으면 건너뛴다
    func addScanPhotos(_ scanPhotos: [ScanPhoto], plan: PlanData) {
        let existing = Set(photos.map(\.id))
        let session = sessions.max { $0.sessionNumber < $1.sessionNumber }
        let encoder = JSONEncoder()
        for scanPhoto in scanPhotos where !existing.contains(scanPhoto.id) {
            let placement = scanPhoto.pose.flatMap { plan.scanAlignment?.placement(of: $0) }
            let roomKey = placement.flatMap { plan.room(containing: $0.position)?.id }
            photos.append(EvidencePhoto(
                id: scanPhoto.id,
                source: .camera,
                roomKey: roomKey,
                takenAt: scanPhoto.takenAt,
                imageData: scanPhoto.imageData,
                thumbnailData: scanPhoto.thumbnailData,
                session: session,
                cameraPoseData: scanPhoto.pose.flatMap { try? encoder.encode($0) },
                placement: placement
            ))
        }
        let placed = scanPhotos.filter { photo in photos.contains { $0.id == photo.id && $0.roomKey != nil } }.count
        Logger(subsystem: "All4You", category: "RoomPlanPhoto")
            .notice("스캔 사진 \(scanPhotos.count)장 저장, 장소 자동 지정 \(placed)장")
    }
}

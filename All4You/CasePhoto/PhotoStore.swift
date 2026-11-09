//
//  PhotoStore.swift
//  All4You
//
//  Created by SIA on 11/9/26.
//

// 화면에 보이는 사건 사진과, 한 사건의 사진을 모아 두는 저장소.
// 사진은 사건의 EvidencePhoto 모델(SwiftData)에 저장하고, 화면은 작은 사진을 읽어 둔 LoadedPhoto를 본다

import Observation
import SwiftData
import UIKit

/// 화면에 보이려고 작은 사진을 읽어 들인 사진 한 장. 저장하는 사진 기록은 EvidencePhoto 모델
struct LoadedPhoto: Identifiable {
    let id: UUID
    /// 목록·도면 핀에 쓰는 작은 사진. 원본을 목록마다 그리면 메모리를 많이 써서 따로 만들어 둔다
    var thumbnail: UIImage
    /// 찍은 시각. 불러온 사진은 사진 앱에 남아 있는 촬영 시각
    let takenAt: Date
    var isBookmarked: Bool
    /// 사진이 찍힌 장소 (Room.id). nil이면 위치 미지정
    var roomKey: String?
    /// 찍거나 불러온 조사 차수. nil이면 차수 없이 들어온 사진이라 모든 차수에서 보인다
    var sessionNumber: Int? = nil
    /// AR로 찍은 사진의 카메라 자세 (ARKit 월드 좌표). 도면의 scanAlignment로 정확한 촬영 위치·방향이 된다
    var cameraPose: ScanCameraPose? = nil
    /// 저장된 사진 기록. 원본은 커서 미리 읽어 두지 않고 볼 때 여기서 읽는다
    fileprivate var record: EvidencePhoto?
    /// 저장하지 않는 사진(미리보기용 저장소)의 원본
    fileprivate var memoryImage: UIImage?

    /// 원본(마크업하면 마크업이 그려진 사진으로 바뀐다). 읽지 못하면 작은 사진
    var image: UIImage {
        memoryImage ?? record.flatMap { UIImage(data: $0.imageData) } ?? thumbnail
    }
}

extension LoadedPhoto {
    /// 목록용 작은 사진의 긴 변 길이 (px)
    private nonisolated static let thumbnailLength: CGFloat = 480

    /// 원본에서 목록용 작은 사진을 만든다. 시간이 걸려서 메인 스레드 밖에서 부른다.
    /// 그래서 메인 전용이 아니라고(nonisolated) 표시한다
    nonisolated static func makeThumbnail(from image: UIImage) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > thumbnailLength else { return image }
        let ratio = thumbnailLength / longest
        let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        return image.preparingThumbnail(of: size) ?? image
    }

    /// 저장된 사진 기록에서 화면용 사진을 만든다. 작은 사진을 읽지 못하면 nil
    fileprivate init?(record: EvidencePhoto) {
        guard let thumbnail = UIImage(data: record.thumbnailData) else { return nil }
        self.init(id: record.id, thumbnail: thumbnail, takenAt: record.takenAt, isBookmarked: record.isBookmarked, roomKey: record.roomKey, sessionNumber: record.session?.sessionNumber, cameraPose: record.cameraPose, record: record)
    }

    /// 도면 위 정확한 촬영 위치·방향. 카메라 자세가 없거나(일반 카메라·사진 앱), 도면에 스캔 변환이 없으면 nil
    func placement(in plan: PlanData) -> PhotoPlacement? {
        guard let cameraPose else { return nil }
        return plan.scanAlignment?.placement(of: cameraPose)
    }
}

/// 한 사건의 사진 모음. 촬영·불러오기·앨범·도면이 함께 본다.
/// 사건을 받으면 그 사건의 사진 모델을 읽고 쓰고, 사건 없이 만들면(미리보기) 메모리에만 둔다.
/// 화면에는 고른 조사 차수의 사진만 보이고, 새 사진은 고른 차수에 들어간다
@MainActor
@Observable
final class PhotoStore {
    /// 이 사건의 모든 차수 사진. 찍은 시각 순서대로 놓인다
    private var allPhotos: [LoadedPhoto] = []
    /// 사진을 저장할 사건. nil이면 저장하지 않는다
    private let fireCase: FireCase?
    /// 지금 고른 조사 차수. 사건 메인 상단의 차수 메뉴가 바꾼다. nil이면 차수를 가리지 않는다
    var sessionNumber: Int?

    init(fireCase: FireCase? = nil) {
        self.fireCase = fireCase
        allPhotos = (fireCase?.photos ?? [])
            .sorted { $0.takenAt < $1.takenAt }
            .compactMap(LoadedPhoto.init(record:))
    }

    /// 고른 차수의 사진. 차수 없이 들어온 사진은 모든 차수에서 보인다
    var photos: [LoadedPhoto] {
        allPhotos.filter { photo in
            guard let sessionNumber, let photoSession = photo.sessionNumber else { return true }
            return photoSession == sessionNumber
        }
    }

    /// 위치 미지정 사진
    var unassignedPhotos: [LoadedPhoto] {
        photos.filter { $0.roomKey == nil }
    }

    func photo(id: UUID) -> LoadedPhoto? {
        photos.first { $0.id == id }
    }

    /// 장소의 사진. roomKey가 nil이면 위치 미지정 사진
    func photos(inRoom roomKey: String?) -> [LoadedPhoto] {
        photos.filter { $0.roomKey == roomKey }
    }

    /// 사진을 더하고 새 id를 돌려준다. 새 사진은 위치 미지정으로 들어온다
    // TODO: 촬영 위치로 장소를 자동 지정하는 단계가 생기면 roomKey를 함께 받기
    @discardableResult
    func add(image: UIImage, thumbnail: UIImage, takenAt: Date, source: PhotoSource) -> UUID {
        var photo = LoadedPhoto(id: UUID(), thumbnail: thumbnail, takenAt: takenAt, isBookmarked: false, roomKey: nil, sessionNumber: sessionNumber)
        if let fireCase, let imageData = Self.jpegData(image), let thumbnailData = Self.jpegData(thumbnail) {
            let session = fireCase.sessions.first { $0.sessionNumber == sessionNumber }
            let record = EvidencePhoto(id: photo.id, source: source, takenAt: takenAt, imageData: imageData, thumbnailData: thumbnailData, session: session)
            fireCase.photos.append(record)
            photo.record = record
        } else {
            photo.memoryImage = image
        }
        allPhotos.append(photo)
        return photo.id
    }

    func delete(id: UUID) {
        guard let index = index(of: id) else { return }
        removeRecord(of: allPhotos[index])
        allPhotos.remove(at: index)
    }

    /// 장소의 사진을 모두 지운다. roomKey가 nil이면 위치 미지정 사진
    func deleteAll(inRoom roomKey: String?) {
        let removed = Set(photos(inRoom: roomKey).map(\.id))
        allPhotos.filter { removed.contains($0.id) }.forEach(removeRecord(of:))
        allPhotos.removeAll { removed.contains($0.id) }
    }

    func toggleBookmark(id: UUID) {
        guard let index = index(of: id) else { return }
        allPhotos[index].isBookmarked.toggle()
        allPhotos[index].record?.isBookmarked = allPhotos[index].isBookmarked
    }

    /// 마크업을 그린 사진으로 바꾼다
    func replaceImage(id: UUID, with image: UIImage, thumbnail: UIImage) {
        guard let index = index(of: id) else { return }
        allPhotos[index].thumbnail = thumbnail
        if let record = allPhotos[index].record, let imageData = Self.jpegData(image), let thumbnailData = Self.jpegData(thumbnail) {
            record.imageData = imageData
            record.thumbnailData = thumbnailData
        } else {
            allPhotos[index].memoryImage = image
        }
    }

    /// 촬영 위치가 있는데 장소가 없는 사진을, 그 위치를 품은 장소에 놓는다. 놓은 사진 수를 돌려준다.
    /// 스캔 때 방을 못 나눴다가 나중에 벽을 고치거나 장소를 나누면 자동으로 들어간다.
    /// 장소가 지워져 가리키는 곳이 없어진 사진도 다시 놓는다. 사람이 직접 놓은 사진(있는 장소)은 건드리지 않는다
    @discardableResult
    func assignUnplacedPhotos(in plan: PlanData) -> Int {
        guard plan.scanAlignment != nil else { return 0 }
        let roomIDs = Set(plan.rooms.map(\.id))
        var assigned = 0
        for index in allPhotos.indices {
            if let roomKey = allPhotos[index].roomKey, roomIDs.contains(roomKey) { continue }
            guard let placement = allPhotos[index].placement(in: plan),
                  let room = plan.room(containing: placement.position) else { continue }
            allPhotos[index].roomKey = room.id
            allPhotos[index].record?.roomKey = room.id
            assigned += 1
        }
        return assigned
    }

    /// 사진을 장소에 놓는다
    func assign(id: UUID, toRoom roomKey: String) {
        guard let index = index(of: id) else { return }
        allPhotos[index].roomKey = roomKey
        allPhotos[index].record?.roomKey = roomKey
    }

    private func index(of id: UUID) -> Int? {
        allPhotos.firstIndex { $0.id == id }
    }

    /// 사진 기록을 저장소에서 지운다 (이미지 파일도 함께 지워진다)
    private func removeRecord(of photo: LoadedPhoto) {
        guard let record = photo.record else { return }
        record.modelContext?.delete(record)
    }

    /// 저장할 JPEG. 사진을 거의 그대로 남기려고 높은 품질로
    private static func jpegData(_ image: UIImage) -> Data? {
        image.jpegData(compressionQuality: Self.jpegQuality)
    }

    private static let jpegQuality: CGFloat = 0.9
}

/// 사진을 찍은 달·하루로 묶은 한 덩어리. 앨범은 달, 사진 불러오기는 하루 단위로 묶는다
struct PhotoDateSection<Item>: Identifiable {
    /// 묶은 기간(그 달·그날)의 시작 시각
    let startDate: Date
    let items: [Item]

    var id: Date { startDate }

    /// 이미 시간 순서로 놓인 항목을 그 순서 그대로 기간(.month, .day)별로 묶는다
    static func group(
        _ items: [Item],
        by component: Calendar.Component,
        date: (Item) -> Date,
        calendar: Calendar = .current
    ) -> [PhotoDateSection] {
        var sections: [PhotoDateSection] = []
        for item in items {
            let itemDate = date(item)
            let startDate = calendar.dateInterval(of: component, for: itemDate)?.start ?? itemDate
            if let last = sections.last, last.startDate == startDate {
                sections[sections.count - 1] = PhotoDateSection(startDate: startDate, items: last.items + [item])
            } else {
                sections.append(PhotoDateSection(startDate: startDate, items: [item]))
            }
        }
        return sections
    }
}

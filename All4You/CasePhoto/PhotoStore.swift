//
//  PhotoStore.swift
//  All4You
//
//  Created by SIA on 11/9/26.
//

// 사건 사진 한 장과, 한 사건의 사진을 모아 두는 저장소
// TEMP: 사진 저장 방식(SwiftData·파일)이 정해지기 전이라 메모리에만 들고 있음 — 앱을 끄면 사진이 사라짐

import Observation
import UIKit

/// 화면에 보이려고 이미지를 읽어 들인 사진 한 장. 저장하는 사진 기록은 ERD 이름을 딴 EvidencePhoto 모델
struct LoadedPhoto: Identifiable {
    let id: UUID
    /// 원본(마크업하면 마크업이 그려진 사진으로 바뀐다)
    var image: UIImage
    /// 목록·도면 핀에 쓰는 작은 사진. 원본을 목록마다 그리면 메모리를 많이 써서 따로 만들어 둔다
    var thumbnail: UIImage
    /// 찍은 시각. 불러온 사진은 사진 앱에 남아 있는 촬영 시각
    let takenAt: Date
    var isBookmarked: Bool
    /// 사진이 찍힌 장소 (Room.id). nil이면 위치 미지정
    var roomKey: String?
}

extension LoadedPhoto {
    /// 목록용 작은 사진의 긴 변 길이 (px)
    private static let thumbnailLength: CGFloat = 480

    /// 원본에서 목록용 작은 사진을 만든다. 시간이 걸려서 메인 스레드 밖에서 부른다
    static func makeThumbnail(from image: UIImage) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > thumbnailLength else { return image }
        let ratio = thumbnailLength / longest
        let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        return image.preparingThumbnail(of: size) ?? image
    }
}

/// 한 사건(현재 조사 차수)의 사진 모음. 촬영·불러오기·앨범·도면이 함께 본다
// TODO: 조사 차수(InvestigationSession)가 생기면 차수별로 나누기
@MainActor
@Observable
final class PhotoStore {
    /// 추가한 순서대로 쌓인다
    private(set) var photos: [LoadedPhoto] = []

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
    func add(image: UIImage, thumbnail: UIImage, takenAt: Date) -> UUID {
        let photo = LoadedPhoto(
            id: UUID(),
            image: image,
            thumbnail: thumbnail,
            takenAt: takenAt,
            isBookmarked: false,
            roomKey: nil
        )
        photos.append(photo)
        return photo.id
    }

    func delete(id: UUID) {
        photos.removeAll { $0.id == id }
    }

    /// 장소의 사진을 모두 지운다. roomKey가 nil이면 위치 미지정 사진
    func deleteAll(inRoom roomKey: String?) {
        photos.removeAll { $0.roomKey == roomKey }
    }

    func toggleBookmark(id: UUID) {
        guard let index = index(of: id) else { return }
        photos[index].isBookmarked.toggle()
    }

    /// 마크업을 그린 사진으로 바꾼다
    func replaceImage(id: UUID, with image: UIImage, thumbnail: UIImage) {
        guard let index = index(of: id) else { return }
        photos[index].image = image
        photos[index].thumbnail = thumbnail
    }

    /// 사진을 장소에 놓는다
    func assign(id: UUID, toRoom roomKey: String) {
        guard let index = index(of: id) else { return }
        photos[index].roomKey = roomKey
    }

    private func index(of id: UUID) -> Int? {
        photos.firstIndex { $0.id == id }
    }
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

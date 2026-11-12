//
//  FloorPlanMemoModels.swift
//  All4You
//
//  Created by 채유성 on 11/09/26.
//

import Foundation

// 도면 위에 메모가 붙은 위치 (도면 좌표로 저장)
struct FloorPlanMemoAnchor: Hashable {
    let x: Double
    let y: Double
    
    var point: SIMD2<Double> { SIMD2(x, y) }
}

// 도면에서 작성 중인 메모 (완료하기 전까지는 메모 목록에 들어가지 않음)
struct FloorPlanMemoDraft: Equatable {
    let anchor: FloorPlanMemoAnchor
    let locationID: String?
    let locationName: String
    var content = ""
    var taggedPhotoIDs: [UUID] = []
    var taggedMarkerIDs: [String] = []
}

struct FloorPlanMemoSection: Identifiable {
    /// Room.id. 방 밖에 남긴 메모는 `unassigned`를 사용
    let id: String
    let locationName: String
    var memos: [FloorPlanMemo]
}

struct FloorPlanMemo: Identifiable {
    let id: UUID
    let title: String
    let createdAt: Date
    let content: String
    let locationID: String?
    let locationName: String
    let anchor: FloorPlanMemoAnchor
    /// 메모에 태그된 사진
    let taggedPhotos: [LoadedPhoto]
    
    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = .now,
        content: String,
        locationID: String?,
        locationName: String,
        anchor: FloorPlanMemoAnchor,
        taggedPhotos: [LoadedPhoto] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.content = content
        self.locationID = locationID
        self.locationName = locationName
        self.anchor = anchor
        self.taggedPhotos = taggedPhotos
    }
    
    var detailTitle: String { title }
    
    var dateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: createdAt)
    }
    
    var timeText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
}

// TODO: 기존 위치 피커 Preview와의 호환을 위한 값. 실제 메모 목록은 Room.id와 이름을 직접 사용해야함
enum FloorPlanMemoLocation: String, CaseIterable, Identifiable {
    case all = "전체"
    case ignitionPoint = "발화지점"
    case mainBedroom = "안방"
    case livingRoom = "거실"
    case room1 = "방1"
    
    var id: Self { self }
}

extension [FloorPlanMemoSection] {
    // 메모를 같은 장소 섹션에 추가하고, 없으면 새 섹션을 만듦
    mutating func append(_ memo: FloorPlanMemo) {
        let sectionID = memo.locationID ?? FloorPlanMemoSectionID.unassigned
        if let index = firstIndex(where: { $0.id == sectionID }) {
            self[index].memos.append(memo)
        } else {
            append(
                FloorPlanMemoSection(
                    id: sectionID,
                    locationName: memo.locationName,
                    memos: [memo]
                )
            )
        }
    }
    
    var allMemos: [FloorPlanMemo] {
        flatMap(\.memos)
    }
    
    static let sample: Self = [
        FloorPlanMemoSection(
            id: "ignition-point",
            locationName: "발화지점",
            memos: [
                FloorPlanMemo(
                    title: "메모 #1",
                    content: "발화지점으로 추정된다. 추가 조사가 필요하다.",
                    locationID: "ignition-point",
                    locationName: "발화지점",
                    anchor: FloorPlanMemoAnchor(x: 0, y: 0)
                )
            ]
        )
    ]
}

enum FloorPlanMemoSectionID {
    static let unassigned = "unassigned"
}

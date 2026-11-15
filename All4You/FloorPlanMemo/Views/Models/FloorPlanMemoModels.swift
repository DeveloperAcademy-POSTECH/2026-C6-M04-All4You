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
    var title: String
    let createdAt: Date
    let content: String
    let locationID: String?
    let locationName: String
    let anchor: FloorPlanMemoAnchor
    /// 메모에 태그된 사진
    let taggedPhotos: [LoadedPhoto]
    /// 메모에 연결된 발화지점 ID와 현재 도면의 발화지점 목록
    let taggedMarkerIDs: [String]
    let ignitionMarkers: [PlanMarker]
    
    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = .now,
        content: String,
        locationID: String?,
        locationName: String,
        anchor: FloorPlanMemoAnchor,
        taggedPhotos: [LoadedPhoto] = [],
        taggedMarkerIDs: [String] = [],
        ignitionMarkers: [PlanMarker] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.content = content
        self.locationID = locationID
        self.locationName = locationName
        self.anchor = anchor
        self.taggedPhotos = taggedPhotos
        self.taggedMarkerIDs = taggedMarkerIDs
        self.ignitionMarkers = ignitionMarkers
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

/// 발화지점 순서를 a...z, aa...로 설정 & 저장된 ID를 메모 본문과 연결
enum FloorPlanMemoIgnitionTags {
    struct Match {
        let range: NSRange
        let markerID: String
    }
    
    static func label(at index: Int) -> String {
        var value = index + 1
        var result = ""
        repeat {
            value -= 1
            result = String(UnicodeScalar(97 + value % 26)!) + result
            value /= 26
        } while value > 0
        return result
    }
    
    static func marker(at label: String, in markers: [PlanMarker]) -> PlanMarker? {
        var index = 0
        for character in label.utf8 {
            guard (97...122).contains(character) else { return nil }
            index = index * 26 + Int(character - 96)
        }
        guard index > 0, markers.indices.contains(index - 1) else { return nil }
        return markers[index - 1]
    }
    
    static func matches(in content: String, markers: [PlanMarker], taggedIDs: [String]) -> [Match] {
        let source = content as NSString
        let matches = (try? NSRegularExpression(pattern: "#[a-z]+(?![a-z0-9])"))?
            .matches(in: content, range: NSRange(location: 0, length: source.length)) ?? []
        return matches.compactMap { match in
            let label = String(source.substring(with: match.range).dropFirst())
            guard let marker = marker(at: label, in: markers), taggedIDs.contains(marker.id) else { return nil }
            return Match(range: match.range, markerID: marker.id)
        }
    }
    
    static func markerIDs(in content: String, tokenByMarkerID: [String: String]) -> [String] {
        let source = content as NSString
        let matches = (try? NSRegularExpression(pattern: "#[a-z]+(?![a-z0-9])"))?
            .matches(in: content, range: NSRange(location: 0, length: source.length)) ?? []
        var markerIDByToken: [String: String] = [:]
        for (id, token) in tokenByMarkerID where markerIDByToken[token] == nil {
            markerIDByToken[token] = id
        }
        var seen = Set<String>()
        return matches.compactMap { markerIDByToken[source.substring(with: $0.range)] }
            .filter { seen.insert($0).inserted }
    }
    
    static func retainedMarkerIDs(from oldContent: String, to newContent: String, markers: [PlanMarker], taggedIDs: [String]) -> [String] {
        let tokens = matches(in: oldContent, markers: markers, taggedIDs: taggedIDs)
        let source = oldContent as NSString
        var byID: [String: String] = [:]
        for token in tokens where byID[token.markerID] == nil {
            byID[token.markerID] = source.substring(with: token.range)
        }
        return markerIDs(in: newContent, tokenByMarkerID: byID)
    }
}

/// 본문에서 삭제된 사진 태그를 메모의 사진 UUID 목록에도 반영
enum FloorPlanMemoPhotoTagReconciler {
    static func photoIDs(in content: String, tokenByPhotoID: [UUID: String]) -> [UUID] {
        var photoIDByToken: [String: UUID] = [:]
        for (id, token) in tokenByPhotoID where photoIDByToken[token] == nil {
            photoIDByToken[token] = id
        }
        return photoTokens(in: content).compactMap { photoIDByToken[$0] }
    }
    
    static func retainedPhotoIDs(
        from oldContent: String,
        to newContent: String,
        taggedPhotoIDs: [UUID]
    ) -> [UUID] {
        let oldTokens = photoTokens(in: oldContent)
        guard oldTokens.count == taggedPhotoIDs.count else { return taggedPhotoIDs }
        
        let photoIDByToken = Dictionary(uniqueKeysWithValues: zip(oldTokens, taggedPhotoIDs))
        return photoTokens(in: newContent).compactMap { photoIDByToken[$0] }
    }
    
    private static func photoTokens(in content: String) -> [String] {
        let source = content as NSString
        let range = NSRange(location: 0, length: source.length)
        let matches = (try? NSRegularExpression(pattern: "#[1-9][0-9]*"))?
            .matches(in: content, range: range) ?? []
        var seen = Set<String>()
        return matches.map { source.substring(with: $0.range) }
            .filter { seen.insert($0).inserted }
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

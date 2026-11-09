//
//  FloorPlanMemoModels.swift
//  All4You
//
//  Created by 채유성 on 11/09/26.
//

import Foundation

struct FloorPlanMemoSection: Identifiable {
    let location: FloorPlanMemoLocation
    let memos: [FloorPlanMemo]
    
    var id: FloorPlanMemoLocation { location }
}

struct FloorPlanMemo: Identifiable {
    let id: Int
    let title: String
    let dateText: String
    let timeText: String
    let detailTitle: String
    let content: String
}

enum FloorPlanMemoLocation: String, CaseIterable, Identifiable {
    case all = "전체"
    case ignitionPoint = "발화지점"
    case mainBedroom = "안방"
    case livingRoom = "거실"
    case room1 = "방1"
    
    var id: Self { self }
}

extension [FloorPlanMemoSection] {
    static let sample: Self = [
        FloorPlanMemoSection(
            location: .ignitionPoint,
            memos: [
                FloorPlanMemo(
                    id: 1,
                    title: "발화#1",
                    dateText: "2026.10.24",
                    timeText: "오후 12:30",
                    detailTitle: "발화지점#1",
                    content: "발화지점으로 추정된다. 하지만 아직은 조사를 더 해봐야 알 것 같다."
                ),
                FloorPlanMemo(
                    id: 2,
                    title: "발화#2",
                    dateText: "2026.10.25",
                    timeText: "오후 2:00",
                    detailTitle: "발화지점#2",
                    content: "발화지점 주변의 흔적을 추가로 확인했다. 정확한 원인은 추가 조사가 필요하다."
                ),
                FloorPlanMemo(
                    id: 3,
                    title: "발화#3",
                    dateText: "2026.10.25",
                    timeText: "오후 2:00",
                    detailTitle: "발화지점#3",
                    content: "현장에서 확인한 발화지점 관련 내용을 기록했다."
                )
            ]
        ),
        FloorPlanMemoSection(
            location: .mainBedroom,
            memos: [
                FloorPlanMemo.sample(id: 4, title: "사진#2", dateText: "2026.10.24", timeText: "오후 12:30"),
                FloorPlanMemo.sample(id: 5, title: "사진#3", dateText: "2026.10.25", timeText: "오후 2:00"),
                FloorPlanMemo.sample(id: 6, title: "사진#5", dateText: "2026.10.25", timeText: "오후 2:00")
            ]
        ),
        FloorPlanMemoSection(
            location: .livingRoom,
            memos: [
                FloorPlanMemo.sample(id: 7, title: "사진#12", dateText: "2026.10.24", timeText: "오후 12:30"),
                FloorPlanMemo.sample(id: 8, title: "사진#15", dateText: "2026.10.25", timeText: "오후 2:00"),
                FloorPlanMemo.sample(id: 9, title: "사진#17", dateText: "2026.10.25", timeText: "오후 2:00")
            ]
        ),
        FloorPlanMemoSection(
            location: .room1,
            memos: [
                FloorPlanMemo.sample(id: 10, title: "사진#12", dateText: "2026.10.24", timeText: "오후 12:30"),
                FloorPlanMemo.sample(id: 11, title: "사진#15", dateText: "2026.10.25", timeText: "오후 2:00")
            ]
        )
    ]
}

private extension FloorPlanMemo {
    static func sample(id: Int, title: String, dateText: String, timeText: String) -> Self {
        FloorPlanMemo(
            id: id,
            title: title,
            dateText: dateText,
            timeText: timeText,
            detailTitle: title,
            content: "현장에서 확인한 내용을 기록한 메모이다."
        )
    }
}

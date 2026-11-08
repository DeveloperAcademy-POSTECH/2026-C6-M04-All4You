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
                FloorPlanMemo(id: 1, title: "발화#1", dateText: "2026.10.24", timeText: "오후 12:30"),
                FloorPlanMemo(id: 2, title: "발화#2", dateText: "2026.10.25", timeText: "오후 2:00"),
                FloorPlanMemo(id: 3, title: "발화#3", dateText: "2026.10.25", timeText: "오후 2:00")
            ]
        ),
        FloorPlanMemoSection(
            location: .mainBedroom,
            memos: [
                FloorPlanMemo(id: 4, title: "사진#2", dateText: "2026.10.24", timeText: "오후 12:30"),
                FloorPlanMemo(id: 5, title: "사진#3", dateText: "2026.10.25", timeText: "오후 2:00"),
                FloorPlanMemo(id: 6, title: "사진#5", dateText: "2026.10.25", timeText: "오후 2:00")
            ]
        ),
        FloorPlanMemoSection(
            location: .livingRoom,
            memos: [
                FloorPlanMemo(id: 7, title: "사진#12", dateText: "2026.10.24", timeText: "오후 12:30"),
                FloorPlanMemo(id: 8, title: "사진#15", dateText: "2026.10.25", timeText: "오후 2:00"),
                FloorPlanMemo(id: 9, title: "사진#17", dateText: "2026.10.25", timeText: "오후 2:00")
            ]
        ),
        FloorPlanMemoSection(
            location: .room1,
            memos: [
                FloorPlanMemo(id: 10, title: "사진#12", dateText: "2026.10.24", timeText: "오후 12:30"),
                FloorPlanMemo(id: 11, title: "사진#15", dateText: "2026.10.25", timeText: "오후 2:00")
            ]
        )
    ]
}

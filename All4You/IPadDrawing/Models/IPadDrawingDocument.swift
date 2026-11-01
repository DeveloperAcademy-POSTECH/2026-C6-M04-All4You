//
//  IPadDrawingDocument.swift
//  All4You
//
//  Created by 김가은 on 11/1/26.
//

import Foundation
import PencilKit

/// iPad 필기 도면의 데이터. 파일 저장은 부모 화면 또는 저장 계층에서 처리
struct IPadDrawingDocument: Identifiable {
    let id: UUID
    var address: String
    var time: String
    var drawing: PKDrawing

    init(
        id: UUID = UUID(),
        address: String,
        time: String,
        drawing: PKDrawing = PKDrawing()
    ) {
        self.id = id
        self.address = address
        self.time = time
        self.drawing = drawing
    }
}

/// 다른 도면 작성 방식에서도 재사용할 수 있는 주석 종류
enum FloorPlanAnnotationCategory: String, CaseIterable {
    case ignition
    case electricity
    case victim
    case room
    case furniture

    var title: String {
        switch self {
        case .ignition: return "발화지점"
        case .electricity: return "전기"
        case .victim: return "피해자"
        case .room: return "공간이름"
        case .furniture: return "가구"
        }
    }
}

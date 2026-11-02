import Foundation
import PencilKit

struct IPadDrawingDocument: Identifiable {
    let id: UUID
    var address: String
    var time: String
    var drawing: PKDrawing
    var stickers: [DrawingSticker]

    init(
        id: UUID = UUID(),
        address: String,
        time: String,
        drawing: PKDrawing = PKDrawing(),
        stickers: [DrawingSticker] = []
    ) {
        self.id = id
        self.address = address
        self.time = time
        self.drawing = drawing
        self.stickers = stickers
    }
}

struct DrawingSticker: Identifiable {
    let id = UUID()
    let category: FloorPlanAnnotationCategory
    var position: CGPoint
    var text = ""
}

enum FloorPlanAnnotationCategory: String, CaseIterable {
    case ignition, electricity, victim, room, furniture

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

//
//  ScanPreviewZone.swift
//  All4You
//
//  Created by 채유성 on 11/5/26.
//

// 저장된 RoomPlan 결과를 2D, 3D 도면으로 표시하는 영역
import RoomPlan
import SwiftUI

struct ScanPreviewArtwork: View {
    let mode: ScanPreviewMode
    let rooms: [CapturedRoom]
    let structure: CapturedStructure?
    let revision: Int
    
    var body: some View {
        Group {
            if rooms.isEmpty {
                // TODO: 예외처리 - 수정 필요할 수 있음
                ContentUnavailableView("표시할 스캔 결과가 없습니다", systemImage: "square.dashed")
            } else {
                switch mode {
                case .twoD:
                    ScanPreview2DFloorPlanView(rooms: rooms, structure: structure)
                case .threeD:
                    RoomPlanScanThumbnailView(
                        rooms: rooms,
                        structure: structure,
                        liveRoom: nil,
                        revision: revision,
                        focusOnLastRoom: false,
                        allowsInteraction: true,
                        showsShadows: false,
                        highlightsWalkableFloor: true
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

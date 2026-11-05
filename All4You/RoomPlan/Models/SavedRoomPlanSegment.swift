//
//  SavedRoomPlanSegment.swift
//  All4You
//
//  Created by 채유성 on 11/3/26.
//

import Foundation
import RoomPlan

// 저장된 구간의 원본 또는 처리 결과 파일 위치와 병합에 사용할 CapturedRoom을 묶는 모델
struct SavedRoomPlanSegment {
    let url: URL
    let room: CapturedRoom?
}

//
//  RoomPlanSegmentDialog.swift
//  All4You
//
//  Created by 채유성 on 11/3/26.
//

// 구간 저장 후 오류 / 저장된 방 개수를 안내하고 촬영 종료 또는 다음 구간 스캔을 선택하는 뷰
// TODO: 디자인에 맞게 수정 필요
import SwiftUI

struct RoomPlanSegmentDialog: View {
    let issue: RoomPlanScanIssue?
    let savedCount: Int
    let onFinish: () -> Void
    let onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 14) {
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 10) {
                Button("촬영 종료", action: onFinish)
                    .buttonStyle(.bordered)
                Button("계속 스캔", action: onContinue)
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
            }
        }
        .padding(20)
        .frame(maxWidth: 320)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
    
    // 용량 한계와 촬영·저장 오류에 따른 안내문구들
    private var title: String {
        switch issue {
        case .approachingLimit, .sceneLimitReached: "스캔 한계에 가까워요"
        case .captureFailed: "스캔이 중단됐어요"
        case .saveFailed: "저장에 실패했어요"
        case nil: "스캔을 이어서 할까요?"
        }
    }
    
    // 오류 원인과 저장된 구간 수에 따른 안내문구들
    private var message: String {
        switch issue {
        case .approachingLimit: "현재 구간을 저장했어요. 계속하면 새 구간에서 스캔합니다."
        case .sceneLimitReached: "RoomPlan 한계로 중단됐어요. 저장된 구간을 확인하고 새 구간에서 계속해 주세요."
        case .captureFailed(let detail): "\(detail)\n저장한 구간 \(savedCount)개를 확인해 주세요."
        case .saveFailed(let detail): "\(detail)\n이 구간은 저장되지 않았을 수 있어요."
        case nil: "저장한 구간 \(savedCount)개 · 계속 스캔하면 다음 구간을 추가합니다."
        }
    }
}

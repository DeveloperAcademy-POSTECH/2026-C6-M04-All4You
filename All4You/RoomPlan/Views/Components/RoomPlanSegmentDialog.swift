//
//  RoomPlanSegmentDialog.swift
//  All4You
//
//  Created by 채유성 on 11/3/26.
//

// 구간 저장 후 오류 / 저장된 방 개수를 안내하고 촬영 종료 또는 다음 구간 스캔을 선택하는 뷰
import SwiftUI

struct RoomPlanSegmentDialog: View {
    let issue: RoomPlanScanIssue?
    let savedCount: Int
    let onFinish: () -> Void
    let onContinue: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .padding(.leading, 7)
                .padding(.top, 10)

            Text(message)
                .font(.system(size: 16))
                .multilineTextAlignment(.leading)
                .padding(.top, 14)
                .padding(.leading, 6)

            HStack(spacing: 8) {
                Button(action: onFinish) {
                    Text("스캔 마치기")
                        .foregroundStyle(.black)
                        .frame(width: 137, height: 48)
                        .font(.system(size: 17, weight: .semibold))
                        .background(.secondary.opacity(0.2), in: Capsule())
                }

                Button(action: onContinue) {
                    Text("계속 스캔")
                        .foregroundStyle(.white)
                        .frame(width: 137, height: 48)
                        .font(.system(size: 17, weight: .semibold))
                        .background(Color("Brand500"), in: Capsule())
                }
            }
            .font(.system(size: 16, weight: .semibold))
            .buttonStyle(.plain)
            .padding(.top, 28)
        }
        .foregroundStyle(.black)
        .padding(14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 38))
        .environment(\.colorScheme, .light)
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
        case nil: "현재까지 스캔은 저장되었어요"
        }
    }
}

#Preview("스캔 구간 저장") {
    RoomPlanSegmentDialog(issue: nil, savedCount: 1, onFinish: {}, onContinue: {})
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.gray)
}

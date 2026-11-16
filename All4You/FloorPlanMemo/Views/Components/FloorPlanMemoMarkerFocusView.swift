//
//  FloorPlanMemoMarkerFocusView.swift
//  All4You
//
//  Created by 채유성 on 11/16/26.
//

// 메모 탭에서 태그한 발화지점을 누르면 목록 영역의 2D 도면에 강조해 보여주는 뷰
import SwiftUI

struct FloorPlanMemoMarkerFocusView: View {
    let planData: PlanData
    let markerID: String
    let onClose: () -> Void
    
    var body: some View {
        GeometryReader { proxy in
            if proxy.size.width > 0, proxy.size.height > 0 {
                Plan2DView(
                    planData: planData,
                    screen: PlanScreen(plan: planData, in: proxy.size, fill: 0.85),
                    focusedMarkerID: markerID,
                    dimsForMemoFocus: true
                )
                .frame(width: proxy.size.width, height: proxy.size.height)
                .allowsHitTesting(false)
            }
        }
        .clipped()
        .overlay(alignment: .topTrailing) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel("도면 닫기")
            // 도면 영역의 오른쪽 끝을 기준으로 버튼 위치 고정
            .offset(x: -4, y: 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .accessibilityLabel("선택한 발화지점을 강조한 도면")
    }
}

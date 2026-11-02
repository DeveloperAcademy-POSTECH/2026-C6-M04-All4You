//
//  PreScanInfo.swift
//  All4You
//
//  Created by 채유성 on 11/1/26.
//

// 스캔 전 확인 사항 뷰
import SwiftUI

struct PreScanInfo: View {
    let onContinue: () -> Void
    
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 32) {
                Text("스캔 전 확인 사항")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 32) {
                    instruction("공간 밝히기", symbol: "light.max", text: "어두운 공간에서는 스캔이 어려울 수 있어요\n주변을 최대한 밝게 해주세요")
                    instruction("벽과 모서리 비추기", symbol: "viewfinder", text: "벽과 모서리를 천천히 비춰 공간을 인식시켜 주세요")
                    instruction("스캔 범위 확인하기", symbol: "arrow.down.left.and.arrow.up.right", text: "스캔 한계에 도달하면 알림이 나타나요\n촬영 완료를 누른 뒤, 계속 스캔을 선택해 촬영을 이어가 주세요")
                }
            }
            .frame(width: 440, alignment: .topLeading)
            
            Spacer(minLength: 0)
            ContinueButton(isEnabled: true, action: onContinue)
        }
        .padding(.horizontal, 92)
        .padding(.vertical, 72)
        .frame(width: 625, height: 780, alignment: .top)
        .background(.background, in: RoundedRectangle(cornerRadius: 26))
        .overlay(alignment: .top) {
            Capsule()
                .fill(.gray.opacity(0.4))
                .frame(width: 38, height: 3)
                .padding(.top, 5)
        }
    }
    
    private func instruction(_ title: String, symbol: String, text: String) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: symbol)
                .font(.title3)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.subheadline.bold())
                Text(text).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

#Preview("스캔 전 확인 사항") {
    PreScanInfo {}
        .padding()
        .background(.gray)
}

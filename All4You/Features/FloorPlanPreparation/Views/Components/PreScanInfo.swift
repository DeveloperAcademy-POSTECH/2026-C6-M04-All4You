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
        VStack(alignment: .leading, spacing: 28) {
            Capsule()
                .fill(.gray.opacity(0.4))
                .frame(width: 38, height: 3)
                .frame(maxWidth: .infinity)
            
            Text("스캔 전 확인 사항")
                .font(.headline)
                .padding(.top, 12)
            
            instruction("공간 밝히기", symbol: "light.max", text: "어두운 공간에서는 스캔이 어려울 수 있어요\n주변을 최대한 밝게 해주세요")
            instruction("벽과 모서리 비추기", symbol: "viewfinder", text: "벽과 모서리를 천천히 비춰 공간을 인식시켜 주세요")
            instruction("스캔 범위 확인하기", symbol: "arrow.down.left.and.arrow.up.right", text: "한 번에 스캔할 수 있는 범위가 정해져 있어요\n알림이 나타나면 촬영 종료 버튼을 누른 뒤,\n이어서 촬영하기 버튼을 눌러 스캔을 계속해 주세요")
            
            Spacer(minLength: 36)
            ContinueButton(isEnabled: true, action: onContinue)
                .padding(.bottom, 28)
        }
        .padding(.horizontal, 40)
        .padding(.top, 6)
        .frame(maxWidth: 480)
        .frame(height: 600)
        .background(.background, in: RoundedRectangle(cornerRadius: 26))
    }
    
    private func instruction(_ title: String, symbol: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
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

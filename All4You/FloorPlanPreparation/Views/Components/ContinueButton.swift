//
//  ContinueButton.swift
//  All4You
//
//  Created by 채유성 on 11/1/26.
//

// "계속" 버튼 컴포넌트
import SwiftUI

struct ContinueButton: View {
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("계속")
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
        }
        .buttonStyle(ContinueButtonStyle(isEnabled: isEnabled))
        .disabled(!isEnabled)
    }
}

private struct ContinueButtonStyle: ButtonStyle {
    let isEnabled: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isEnabled ? .white : .secondary)
            .background(isEnabled ? .black : Color(uiColor: .systemGray5), in: Capsule())
            .opacity(configuration.isPressed && isEnabled ? 0.7 : 1)
    }
}

#Preview {
    VStack(spacing: 16) {
        ContinueButton(isEnabled: true) {}
        ContinueButton(isEnabled: false) {}
    }
    .padding()
}

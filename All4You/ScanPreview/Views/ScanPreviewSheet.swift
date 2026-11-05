//
//  ScanPreviewSheet.swift
//  All4You
//
//  Created by 채유성 on 11/5/26.
//

// 스캔 결과 미리보기 Sheet
import SwiftUI

struct ScanPreviewSheet: View {
    @State private var selectedMode: ScanPreviewMode = .twoD
    
    let onContinue: () -> Void
    let onChooseOtherMethod: () -> Void
    let onRescan: () -> Void
    
    init(
        initialMode: ScanPreviewMode = .twoD,
        onContinue: @escaping () -> Void,
        onChooseOtherMethod: @escaping () -> Void,
        onRescan: @escaping () -> Void
    ) {
        _selectedMode = State(initialValue: initialMode)
        self.onContinue = onContinue
        self.onChooseOtherMethod = onChooseOtherMethod
        self.onRescan = onRescan
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Capsule()
                    .fill(Color(uiColor: .systemGray3))
                    .frame(width: 58, height: 4)
                    .padding(.top, 7)
                
                Text("도면 미리보기")
                    .font(.system(size: 24, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 90)
                    .padding(.top, 57)
                
                ScanPreviewModePicker(selection: $selectedMode)
                    .padding(.top, 18)
                
                ScanPreviewArtwork()
                    .frame(maxWidth: 500)
                    .frame(height: 350)
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
                
                Spacer(minLength: 12)
                
                VStack(spacing: 14) {
                    Button(action: onContinue) {
                        Text("이 도면으로 계속하기")
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(.black, in: Capsule())
                    }
                    
                    Button(action: onChooseOtherMethod) {
                        Text("다른 방법으로 도면 그리기")
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(uiColor: .systemGray5), in: Capsule())
                    }
                }
                .font(.system(size: 17, weight: .medium))
                .buttonStyle(.plain)
                .frame(width: 355)
                
                Button("다시 스캔하기", action: onRescan)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color("Brand500"))
                    .buttonStyle(.plain)
                    .padding(.top, 30)
                    .padding(.bottom, 47)
            }
            .frame(width: min(625, geometry.size.width - 28),
                   height: min(780, geometry.size.height - 24))
            .background(.white, in: RoundedRectangle(cornerRadius: 35))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview("도면 미리보기") {
    ScanPreviewSheet(onContinue: {}, onChooseOtherMethod: {}, onRescan: {})
        .background(Color.gray.opacity(0.45))
}

#Preview("도면 미리보기 3D") {
    ScanPreviewSheet(initialMode: .threeD, onContinue: {}, onChooseOtherMethod: {}, onRescan: {})
        .background(Color.gray.opacity(0.45))
}


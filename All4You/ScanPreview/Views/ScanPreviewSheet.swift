//
//  ScanPreviewSheet.swift
//  All4You
//
//  Created by 채유성 on 11/5/26.
//

// 저장된 RoomPlan 결과를 받아 2D·3D 미리보기를 제공하는 Sheet
import RoomPlan
import SwiftUI

struct ScanPreviewSheet: View {
    @State private var selectedMode: ScanPreviewMode = .twoD
    let rooms: [CapturedRoom]
    let structure: CapturedStructure?
    let revision: Int
    let statusMessage: String?
    
    let onContinue: () -> Void
    let onChooseOtherMethod: () -> Void
    let onRescan: () -> Void
    
    init(
        initialMode: ScanPreviewMode = .twoD,
        rooms: [CapturedRoom] = [],
        structure: CapturedStructure? = nil,
        revision: Int = 0,
        isContinueEnabled: Bool = true,
        statusMessage: String? = nil,
        onContinue: @escaping () -> Void,
        onChooseOtherMethod: @escaping () -> Void,
        onRescan: @escaping () -> Void
    ) {
        _selectedMode = State(initialValue: initialMode)
        self.rooms = rooms
        self.structure = structure
        self.revision = revision
        self.statusMessage = statusMessage
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
                
                ScanPreviewArtwork(
                    mode: selectedMode,
                    rooms: rooms,
                    structure: structure,
                    revision: revision
                )
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

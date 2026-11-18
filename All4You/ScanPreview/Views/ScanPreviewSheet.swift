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
    /// 있으면 버튼 위에 안내로 보인다
    let statusMessage: String?
    
    let onContinue: () -> Void
    let onChooseOtherMethod: () -> Void
    let onRescan: () -> Void
    let onResumeScan: (() -> Void)?
    let isResumeEnabled: Bool
    let isInterrupted: Bool
    
    init(
        initialMode: ScanPreviewMode = .twoD,
        rooms: [CapturedRoom] = [],
        structure: CapturedStructure? = nil,
        revision: Int = 0,
        statusMessage: String? = nil,
        onContinue: @escaping () -> Void,
        onChooseOtherMethod: @escaping () -> Void,
        onRescan: @escaping () -> Void,
        onResumeScan: (() -> Void)? = nil,
        isResumeEnabled: Bool = true,
        isInterrupted: Bool = false
    ) {
        _selectedMode = State(initialValue: initialMode)
        self.rooms = rooms
        self.structure = structure
        self.revision = revision
        self.statusMessage = statusMessage
        self.onContinue = onContinue
        self.onChooseOtherMethod = onChooseOtherMethod
        self.onRescan = onRescan
        self.onResumeScan = onResumeScan
        self.isResumeEnabled = isResumeEnabled
        self.isInterrupted = isInterrupted
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
                    .padding(.top, 48)
                
                ScanPreviewModePicker(selection: $selectedMode)
                    .padding(.top, 18)
                
                if let statusMessage {
                    VStack(spacing: 3) {
                        ForEach(Array(statusMessage.components(separatedBy: "\n").enumerated()), id: \.offset) { item in
                            Text(item.element)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .font(AppTypography.subheadline)
                    .foregroundStyle(Color("Brand500"))
                    .multilineTextAlignment(.center)
                    .frame(width: 480)
                    .padding(.top, 14)
                }
                
                ScanPreviewArtwork(
                    mode: selectedMode,
                    rooms: rooms,
                    structure: structure,
                    revision: revision
                )
                .frame(maxWidth: 500)
                .frame(height: 320)
                .padding(.horizontal, 24)
                .padding(.top, statusMessage == nil ? 28 : 18)
                
                Spacer(minLength: 0)
                
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
                
                HStack(spacing: 12) {
                    if let onResumeScan {
                        Button(action: onResumeScan) {
                            Label("스캔 이어하기", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .foregroundStyle(isInterrupted ? Color.white : Color.primary)
                                .background(
                                    isInterrupted ? Color("Brand500") : Color(uiColor: .systemGray5),
                                    in: Capsule()
                                )
                        }
                        .disabled(!isResumeEnabled)
                        .opacity(isResumeEnabled ? 1 : 0.4)
                    }
                    Button(action: onRescan) {
                        Label("다시 스캔하기", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .foregroundStyle(.primary)
                            .background(Color(uiColor: .systemGray5), in: Capsule())
                    }
                }
                .font(.system(size: 15, weight: .semibold))
                .buttonStyle(.plain)
                .frame(width: 355)
                .padding(.top, 18)
                .padding(.bottom, 64)
            }
            .frame(width: min(625, geometry.size.width - 28),
                   height: min(780, geometry.size.height - 24))
            .background(.white, in: RoundedRectangle(cornerRadius: 35))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

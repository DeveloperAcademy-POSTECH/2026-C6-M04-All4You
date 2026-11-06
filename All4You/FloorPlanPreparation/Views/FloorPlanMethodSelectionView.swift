//
//  FloorPlanMethodSelectionView.swift
//  All4You
//
//  Created by 채유성 on 11/1/26.
//

import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit

// 평면도 생성 방식 선택 화면
// 이전 화면에서 주소, 생성 시각은 전달받음
// 계속 버튼을 누르면 선택한 방식에 따라 이 View에서 다음 화면으로 이동함
struct FloorPlanMethodSelectionView: View {
    let address: String
    let createdAt: Date
    @Environment(\.dismiss) private var dismiss
    
    // 선택 상태와 이동 상태를 분리 (항목을 누르는 것만으로 화면이 이동하지 않도록 방지)
    @State private var selectedSourceType: FloorPlanSourceType?
    @State private var destination: FloorPlanSourceType?
    @State private var isImportMenuPresented = false
    @State private var isPhotoPickerPresented = false
    @State private var isFileImporterPresented = false
    @State private var isCameraPresented = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(uiColor: .systemGray6)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("평면도를 어떻게 준비할까요?")
                            .font(.title2.bold())
                        
                        GlassEffectContainer(spacing: 12) {
                            VStack(spacing: 15) {
                                ForEach(FloorPlanSourceType.allCases) { sourceType in
                                    FloorPlanMethodRow(
                                        sourceType: sourceType,
                                        isSelected: selectedSourceType == sourceType
                                    ) {
                                        // 같은 항목을 다시 누르면 선택을 해제하고 계속 버튼도 비활성화
                                        selectedSourceType = selectedSourceType == sourceType ? nil : sourceType
                                        // 외부 가져오기 메뉴는 해당 항목이 선택되어 있을 때만 표시
                                        isImportMenuPresented = selectedSourceType == .externalImport
                                    }
                                    .frame(height: 80)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: 642)
                .padding(EdgeInsets(top: 169, leading: 24, bottom: 24, trailing: 24))
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            FloorPlanPreparationHeader(address: address, createdAt: createdAt) {
                dismiss()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            continueButton
                .frame(maxWidth: 642)
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity)
        }
        .overlay(alignment: .center) {
            if isImportMenuPresented {
                ExternalImportGlassMenu(
                    onCameraTap: {
                        isImportMenuPresented = false
                        openCamera()
                    },
                    onPhotoLibraryTap: {
                        isImportMenuPresented = false
                        isPhotoPickerPresented = true
                    },
                    onFileTap: {
                        isImportMenuPresented = false
                        isFileImporterPresented = true
                    }
                )
                .offset(x: 380, y: 100)
                .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .topLeading)))
            }
        }
        .animation(.snappy, value: isImportMenuPresented)
        // TODO: 실제 화면으로 교체 (이 View를 사용하는 쪽에는 NavigationStack이 있어야 함)
        .navigationDestination(item: $destination) { sourceType in
            switch sourceType {
            case .roomPlan:
                // TODO: PreScanChecklistView(address: address, createdAt: createdAt) 연결
//                RoomPlanScanView()
                Text("굿굿띠")
            case .iPadDrawing:
                // TODO: 직접 그리기 화면 연결
                Text("직접 그리기 화면 준비 중")
            case .externalImport:
                // 외부 가져오기는 ExternalImportGlassMenu로 처리하기에 다른 뷰로 이동하지 않지만 우선 놔둠
                EmptyView()
            }
        }
        .photosPicker(
            isPresented: $isPhotoPickerPresented,
            selection: $selectedPhotoItem,
            matching: .images
        )
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.image, .pdf]
        ) { _ in }
            .fullScreenCover(isPresented: $isCameraPresented) {
                CameraPicker { _ in
                    // TODO: 도면 변환 로직 연결
                }
                .ignoresSafeArea()
            }
    }
    
    private var continueButton: some View {
        ContinueButton(isEnabled: selectedSourceType != nil) {
            guard let selectedSourceType else { return }
            switch selectedSourceType {
            case .roomPlan, .iPadDrawing:
                // 룸플랜 스캔 & 직접 그리기는 다른 화면으로 이동
                isImportMenuPresented = false
                destination = selectedSourceType
            case .externalImport:
                // 별도 선택 화면 없이 ExternalImportGlassMenu 표시
                isImportMenuPresented = true
            }
        }
    }
    
    private func openCamera() {
        // 카메라가 없는 시뮬레이터에서는 UIImagePickerController 실행 막기 (크래시 방지)
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { return }
        isCameraPresented = true
    }
}

#Preview("평면도 준비") {
    NavigationStack {
        FloorPlanMethodSelectionView(
            address: "압구정동 462-2",
            createdAt: .now
        )
    }
}

//
//  FloorPlanAlbumView.swift
//  All4You
//
//  Created by 김가은 on 11/8/26.
//

import PhotosUI
import SwiftUI

struct FloorPlanAlbumView: View {
    // 확정한 사진을 크롭 흐름으로 전달한다.
    let onConfirm: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selection: [PhotosPickerItem] = []
    // 체크를 눌렀을 때만 선택한 사진을 불러온다.
    @State private var itemToLoad: PhotosPickerItem?

    private var isLoading: Bool { itemToLoad != nil }
    @State private var showsLoadError = false

    var body: some View {
        NavigationStack {
            PhotosPicker(
                "사진",
                selection: $selection,
                maxSelectionCount: 1,
                selectionBehavior: .continuous,
                matching: .images
            )
            .photosPickerStyle(.inline)
            .disabled(isLoading)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("사진")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("선택 확인", systemImage: "checkmark") {
                        itemToLoad = selection.first
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderedProminent)
                    .tint(.brand500)
                    .disabled(selection.isEmpty || isLoading)
                }
            }
            .overlay {
                if isLoading {
                    ProgressView("사진 불러오는 중")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .task(id: itemToLoad) {
                guard let item = itemToLoad else { return }
                await loadPhoto(item)
            }
            .alert("사진을 불러오지 못했어요", isPresented: $showsLoadError) {
                Button("확인", role: .cancel) {}
            }
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem) async {
        defer { itemToLoad = nil }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let photo = UIImage(data: data) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            try Task.checkCancellation()
            onConfirm(photo)
        } catch {
            guard !Task.isCancelled else { return }
            selection = []
            showsLoadError = true
        }
    }
}

//
//  IPadDrawingView.swift
//  All4You
//
//  Created by 김가은 on 11/1/26.
//

import SwiftUI

// 문서 소유권과 저장 처리는 부모 화면
struct IPadDrawingView: View {
    @Binding var document: IPadDrawingDocument
    var onBack: () -> Void = {}
    var onDone: (IPadDrawingDocument) -> Void = { _ in }

    // 선택 상태는 화면에만 필요하므로 View에서 관리합니다.
    @State private var selectedCategory: FloorPlanAnnotationCategory?

    var body: some View {
        ZStack(alignment: .top) {
            Color.white.ignoresSafeArea()

            IPadDrawingKit(drawing: $document.drawing)
                .ignoresSafeArea(edges: .bottom)

            VStack(alignment: .leading, spacing: 30) {
                HStack(alignment: .center, spacing: 12) {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 21, weight: .medium))
                            .foregroundStyle(.black)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(Circle().stroke(.black.opacity(0.05)))
                    }
                    .accessibilityLabel("뒤로")

                    VStack(alignment: .leading, spacing: 3) {
                        Text(document.address)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.black)
                        Text(document.time)
                            .font(.system(size: 15))
                            .foregroundStyle(.gray)
                    }

                    Spacer(minLength: 16)

                    Button { onDone(document) } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 27, weight: .regular))
                            .foregroundStyle(.white)
                            .frame(width: 50, height: 50)
                            .background(Color(red: 0, green: 0.55, blue: 1), in: Circle())
                    }
                    .accessibilityLabel("그리기 완료")
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(FloorPlanAnnotationCategory.allCases, id: \.self) { category in
                            Button {
                                selectedCategory = selectedCategory == category ? nil : category
                            } label: {
                                VStack(spacing: 3) {
                                    Image(systemName: category.symbol)
                                        .font(.system(size: 25, weight: .medium))
                                        .frame(height: 27)
                                    Text(category.title)
                                        .font(.system(size: 10, weight: .medium))
                                }
                                .foregroundStyle(selectedCategory == category ? Color.blue : .black)
                                .frame(width: 72, height: 52)
                                .background(
                                    selectedCategory == category
                                        ? Color.blue.opacity(0.12)
                                        : Color(white: 0.93),
                                    in: Capsule()
                                )
                            }
                            .accessibilityAddTraits(selectedCategory == category ? .isSelected : [])
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .buttonStyle(.plain)
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.light)
    }
}

private extension FloorPlanAnnotationCategory {
    var symbol: String {
        switch self {
        case .ignition: return "flame"
        case .electricity: return "bolt.fill"
        case .victim: return "figure.fall"
        case .room: return "character.textbox"
        case .furniture: return "sofa"
        }
    }
}

private struct IPadDrawingPreview: View {
    @State private var document = IPadDrawingDocument(
        address: "압구정동 462-2",
        time: "오후 13:30"
    )

    var body: some View {
        IPadDrawingView(document: $document)
    }
}

struct IPadDrawingView_Previews: PreviewProvider {
    static var previews: some View {
        IPadDrawingPreview()
            .previewInterfaceOrientation(.landscapeLeft)
    }
}

#if os(iOS)
import SwiftUI

// 사용하는 PencilKit 도구 구성 API가 iPadOS 18 이상에서 지원됩니다.
@available(iOS 18.0, *)
struct IPadDrawingView: View {
    @Binding var document: IPadDrawingDocument
    var onBack: () -> Void = {}
    var onDone: (IPadDrawingDocument) -> Void = { _ in }

    @State private var selectedCategory: FloorPlanAnnotationCategory?
    // 공간 이름 입력창의 표시 여부입니다.
    @State private var showsRoomInput = false
    // 입력 중인 이름과, 입력창을 열기 전에 탭한 배치 위치를 잠시 보관합니다.
    @State private var roomName = ""
    @State private var roomPosition = CGPoint.zero

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            stickerToolbar

            // 사용 가능한 도면 영역의 크기를 읽어 스티커 이동 범위에 사용합니다.
            GeometryReader { geometry in
                // 아래부터 필기 캔버스 → 배치용 투명 영역 → 스티커 순서로 겹칩니다.
                ZStack(alignment: .topLeading) {
                    // Global에 있는 공용 PencilKit View입니다.
                    // $는 값을 복사하는 대신, 원본을 읽고 수정할 수 있는 Binding을 전달합니다.
                    IPadDrawingKit(
                        drawing: $document.drawing,
                        // 스티커 배치 또는 이름 입력 중에는 선이 그려지지 않게 합니다.
                        isDrawingEnabled: selectedCategory == nil && !showsRoomInput
                    )

                    // 스티커를 선택한 동안만 탭을 받습니다.
                    if selectedCategory != nil {
                        Color.clear
                            // 투명한 영역도 탭을 받을 수 있도록 터치 모양을 지정합니다.
                            .contentShape(Rectangle())
                            .onTapGesture { position in
                                placeSticker(at: position)
                            }
                    }

                    // 각 스티커도 Binding으로 전달하므로 드래그한 위치가 Model에 반영됩니다.
                    ForEach($document.stickers) { $sticker in
                        DrawingStickerView(sticker: $sticker, canvasSize: geometry.size)
                            // 스티커를 길게 누르면 삭제 메뉴를 보여줍니다.
                            .contextMenu {
                                Button("삭제", role: .destructive) {
                                    document.stickers.removeAll { $0.id == sticker.id }
                                }
                            }
                    }
                }
                // 스티커 드래그 시 이 도면 영역을 기준으로 좌표를 계산합니다.
                .coordinateSpace(name: "drawingCanvas")
                // 도면 영역 밖으로 나간 내용은 보이지 않게 자릅니다.
                .clipped()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .background(.white)
        .foregroundStyle(.black)
        .buttonStyle(.plain)
        .navigationBarTitleDisplayMode(.inline)
        // Global/Toolbar.swift의 공용 툴바에 현재 문서 제목과 시간을 전달합니다.
        .titledBothSidesToolbar(
            title: document.address,
            subtitle: document.time,
            onBack: onBack,
            onDone: { onDone(document) }
        )
        .preferredColorScheme(.light)
        // showsRoomInput이 true가 되면 이름 입력창이 열립니다.
        .alert("공간 이름", isPresented: $showsRoomInput) {
            TextField("예: 안방", text: $roomName)
            Button("취소", role: .cancel) {}
            Button("추가") {
                // 앞뒤 공백을 지우고, 이름이 비어 있으면 스티커를 추가하지 않습니다.
                let name = roomName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                document.stickers.append(DrawingSticker(
                    category: .room, position: roomPosition, text: name
                ))
            }
        }
    }

    // 상단 스티커 종류 버튼들입니다. 도면 자체가 아니라 선택 모드만 바꿉니다.
    private var stickerToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(FloorPlanAnnotationCategory.allCases, id: \.self) { category in
                    Button {
                        // 같은 버튼을 다시 누르면 선택 해제, 다른 버튼이면 종류를 바꿉니다.
                        if selectedCategory == category {
                            selectedCategory = nil
                        } else {
                            selectedCategory = category
                        }
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: category.symbol)
                                .font(.system(size: 24))
                                .frame(height: 27)
                            Text(category.title).font(.system(size: 10))
                        }
                        .frame(width: 72, height: 52)
                        .background(
                            stickerButtonColor(for: category),
                            in: Capsule()
                        )
                    }
                    .accessibilityAddTraits(stickerButtonTraits(for: category))
                }
            }
        }
    }

    // 선택한 버튼은 파란색, 나머지는 회색으로 표시합니다.
    private func stickerButtonColor(for category: FloorPlanAnnotationCategory) -> Color {
        if selectedCategory == category {
            return Color.blue.opacity(0.15)
        } else {
            return Color.gray.opacity(0.12)
        }
    }

    // VoiceOver에도 버튼이 선택되었는지 전달합니다.
    private func stickerButtonTraits(for category: FloorPlanAnnotationCategory) -> AccessibilityTraits {
        if selectedCategory == category {
            return .isSelected
        } else {
            return []
        }
    }

    // 도면에서 탭한 위치를 받아 스티커를 배치합니다.
    private func placeSticker(at position: CGPoint) {
        guard let category = selectedCategory else { return }
        // 공간 이름은 텍스트가 필요하므로 위치만 기억하고 입력창부터 엽니다.
        if category == .room {
            roomPosition = position
            roomName = ""
            showsRoomInput = true
        } else {
            document.stickers.append(DrawingSticker(category: category, position: position))
        }
        // 한 번 배치하면 선택을 해제합니다. 이름 입력창까지 닫히면 다시 필기할 수 있습니다.
        selectedCategory = nil
    }
}

// 스티커 한 개를 표시하고 이동시키는 작은 View입니다. 이 파일 안에서만 사용합니다.
private struct DrawingStickerView: View {
    // 부모 배열에 들어 있는 스티커를 직접 수정할 수 있도록 전달받습니다.
    @Binding var sticker: DrawingSticker
    let canvasSize: CGSize
    // 드래그 시작 위치를 기억해야 이동량이 매번 중복해서 더해지지 않습니다.
    @State private var dragStart: CGPoint?

    var body: some View {
        Group {
            // 공간 이름은 검정 캡슐 안의 글자, 나머지 종류는 SF Symbols 아이콘입니다.
            if sticker.category == .room {
                Text(sticker.text)
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.black, in: Capsule())
            } else {
                Image(systemName: sticker.category.symbol)
                    .font(.system(size: 30))
                    .foregroundStyle(stickerColor)
            }
        }
        // 작은 아이콘도 손가락으로 잡기 쉽도록 터치 영역을 확보합니다.
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        // position은 도면 좌표에서 스티커 중심의 위치입니다.
        .position(sticker.position)
        .gesture(
            DragGesture(coordinateSpace: .named("drawingCanvas"))
                .onChanged { value in
                    if dragStart == nil { dragStart = sticker.position }
                    guard let start = dragStart else { return }
                    // 시작 위치 + 손가락 이동량으로 새 위치를 계산합니다.
                    // min/max는 스티커 중심이 도면의 가로·세로 범위를 벗어나지 않도록 제한합니다.
                    sticker.position = CGPoint(
                        x: min(max(0, start.x + value.translation.width), canvasSize.width),
                        y: min(max(0, start.y + value.translation.height), canvasSize.height)
                    )
                }
                // 다음 드래그는 새 시작 위치를 기억하도록 초기화합니다.
                .onEnded { _ in dragStart = nil }
        )
        // VoiceOver가 아이콘 대신 스티커의 의미나 공간 이름을 읽도록 합니다.
        .accessibilityLabel(stickerAccessibilityLabel)
    }

    // 발화지점만 주황색으로 표시합니다.
    private var stickerColor: Color {
        if sticker.category == .ignition {
            return .orange
        } else {
            return .black
        }
    }

    // 공간 스티커는 입력한 이름을, 다른 스티커는 종류 이름을 읽습니다.
    private var stickerAccessibilityLabel: String {
        if sticker.category == .room {
            return sticker.text
        } else {
            return sticker.category.title
        }
    }

}

// Model의 종류를 화면에서 사용할 SF Symbols 이름으로 연결합니다.
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

@available(iOS 18.0, *)
#Preview("iPad 도면 그리기", traits: .landscapeLeft) {
    @Previewable @State var document = IPadDrawingDocument(
        address: "압구정동 462-2",
        time: "오후 13:30"
    )

    NavigationStack {
        IPadDrawingView(document: $document)
    }
}
#endif

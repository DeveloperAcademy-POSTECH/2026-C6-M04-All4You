// 사건 작업 메인 화면. 상단 바와 도면·앨범·메모 탭으로 구성된다

import SwiftData
import SwiftUI

/// 도면·앨범·메모를 오가며 사건을 작업하는 화면
struct CaseMainView: View {
    /// 작업 중인 사건. 상단 바의 사건명·조사 차수를 여기서 읽는다
    let fireCase: FireCase
    /// 도면 탭에 그릴 도면. 장소(Room)는 앨범·사진 위치에도 쓴다
    let planData: PlanData
    /// 이 사건의 사진. 메인을 닫았다 다시 열어도 사진이 남도록 바깥(CaseFlowView)이 들고 있다
    let photoStore: PhotoStore
    // 뒤로가기, 편집하기(펜 아이콘)
    let onBack: () -> Void
    let onEdit: () -> Void
    
    // 탭을 오가도 고른 값이 남도록 탭이 아니라 이 화면이 기억한다
    @State private var photoFilter = PhotoFilter()
    // 사이드바에서 고른 줄. 도면의 2D·3D도 여기서 정해진다
    @State private var selection = CaseTabSelection.floorPlan2D
    // 이 사건에서 작성한 메모. 장소별 목록과 도면 핀이 같은 값을 본다
    @State private var memoSections: [FloorPlanMemoSection] = []
    // 메모 추가 버튼을 누른 뒤 도면에서 위치를 고르고 있는지와 작성 중인 내용
    @State private var isAddingMemo = false
    @State private var memoDraft: FloorPlanMemoDraft?
    // 메모 작성을 시작할 때 도면의 확대·이동을 초기화해 메모 핀과 도면 좌표를 맞춘다
    @State private var floorPlanPresentationID = UUID()
    // 거절된 권한. 값이 있으면 설정 앱으로 안내하는 알림이 뜬다
    @State private var deniedPermission: DeniedPermission?
    // 사진 촬영 화면, 사진 불러오기 시트, 도면 탭의 위치 미확인 사진 패널
    @State private var isCapturingPhoto = false
    @State private var isImportingPhoto = false
    @State private var isPlacingPhotos = false
    // 사진 불러오기 시트를 화면 크기에 맞추려고 잰 이 화면의 크기
    @State private var screenSize: CGSize = .zero
    @State private var isExportSheetPresented = false
    /// 상단 바에서 고른 조사 차수. 처음에는 가장 최근 차수
    @State private var sessionNumber: Int
    
    init(fireCase: FireCase, planData: PlanData, photoStore: PhotoStore, onBack: @escaping () -> Void, onEdit: @escaping () -> Void) {
        self.fireCase = fireCase
        self.planData = planData
        self.photoStore = photoStore
        self.onBack = onBack
        self.onEdit = onEdit
        _sessionNumber = State(initialValue: fireCase.sessions.map(\.sessionNumber).max() ?? 1)
    }
    
    var body: some View {
        CaseTabView(
            selection: $selection,
            albumRows: albumRows,
            memoRows: memoRows,
            albumBadge: photoStore.unassignedPhotos.count,
            onClearRow: clearRow,
            leadingHeader: AnyView(titleHeader)
        ) {
            withCaseToolbars(floorPlanTab)
        } album: {
            albumTab
        } memo: {
            withCaseToolbars(FloorPlanMemoView(sections: memoSections))
        }
        // 고른 차수의 사진만 보이고, 새 사진은 고른 차수에 들어가게 사진 모음에 알린다
        .onChange(of: sessionNumber, initial: true) {
            photoStore.sessionNumber = sessionNumber
        }
        // 상단 바는 탭마다 붙지만 알림은 화면에 하나만 있으면 되므로 탭 바깥에 붙인다
        .alert(
            deniedPermission?.title ?? "",
            isPresented: isDeniedAlertShown,
            presenting: deniedPermission
        ) { _ in
            Button(Copy.openSettings) {
                PermissionService.openSettings()
            }
            Button(Copy.cancel, role: .cancel) {}
        } message: { permission in
            Text(permission.message)
        }
        // 처음 그려질 때 크기부터 바로 잰다 (크기가 바뀔 때만 알려 주는 방식은 처음 값을 놓쳐 시트가 아주 작게 떴음)
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        screenSize = proxy.size
                    }
                    .onChange(of: proxy.size) { _, size in
                        screenSize = size
                    }
            }
        }
        .fullScreenCover(isPresented: $isCapturingPhoto) {
            PhotoCaptureView(store: photoStore) {
                isCapturingPhoto = false
            }
        }
        .sheet(isPresented: $isImportingPhoto) {
            PhotoLibrarySheet { photos in
                for photo in photos {
                    photoStore.add(image: photo.image, thumbnail: photo.thumbnail, takenAt: photo.takenAt, source: .photoLibrary)
                }
            }
            .presentationSizing(PhotoLibrarySheetSizing(containerSize: screenSize))
        }
        .sheet(isPresented: $isExportSheetPresented) {
            FloorPlanExportView { configuration in
                // TODO: configuration(사용자가 선택한 저장 옵션 및 도면 타입)을 이용해 실제 저장 로직 구현
                print("저장됨: \(configuration)")
            }
        }
    }
}

// 탭
extension CaseMainView {
    /// 도면 아래 2D·3D 막대와 사이드바의 2D·3D 줄이 같은 값을 보도록 고른 줄에서 만든다
    private var dimension: Binding<FloorPlanTabView.Dimension> {
        Binding(
            get: { selection == .floorPlan3D ? .threeD : .twoD },
            set: { selection = $0 == .threeD ? .floorPlan3D : .floorPlan2D }
        )
    }
    
    private var floorPlanTab: some View {
        FloorPlanTabView(
            photoFilter: $photoFilter,
            dimension: dimension,
            planData: planData,
            photoStore: photoStore,
            isPlacingPhotos: $isPlacingPhotos
        )
        .id(floorPlanPresentationID)
        .overlay {
            FloorPlanMemoPlacementOverlay(
                planData: planData,
                memos: memoSections.allMemos,
                isPresented: $isAddingMemo,
                draft: $memoDraft,
                onSave: addMemo,
                onCancel: cancelAddingMemo
            )
        }
    }
    
    /// 전체 보기에는 사건 상단 바를, 장소 하나를 볼 때는 Figma처럼 뒤로가기만 둔다. 뒤로가면 전체 보기로 간다
    @ViewBuilder
    private var albumTab: some View {
        let album = CaseAlbumView(
            photoStore: photoStore,
            rooms: planData.rooms,
            selection: $selection,
            onPlaceUnassigned: showPhotoPlacement
        )
        if case .album = selection {
            album
                .navigationBarTitleDisplayMode(.inline)
                .backOnlyToolbar {
                    selection = .albumOverview
                }
        } else {
            withCaseToolbars(album)
        }
    }
    
    // 사이드바 앨범 구역의 줄: 위치 미지정, 그다음 도면의 장소 순서. 숫자는 그 장소의 사진 수
    private var albumRows: [CaseSidebarRow] {
        let unassignedRow = CaseSidebarRow(
            name: CaseAlbumView.unassignedName,
            systemImage: "photo.badge.exclamationmark",
            count: photoStore.unassignedPhotos.count
        )
        let roomRows = planData.rooms.map { room in
            CaseSidebarRow(
                name: room.name,
                systemImage: Self.systemImage(forRoom: room.name),
                count: photoStore.photos(inRoom: room.id).count
            )
        }
        return [unassignedRow] + roomRows
    }
    
    // 사이드바에는 도면의 모든 장소를 보이고, 장소 밖 메모가 있을 때만 "기타"를 덧붙인다.
    private var memoRows: [CaseSidebarRow] {
        let roomRows = planData.rooms.map { room in
            CaseSidebarRow(
                name: room.name,
                systemImage: Self.systemImage(forRoom: room.name),
                count: memoSections.first(where: { $0.id == room.id })?.memos.count ?? 0
            )
        }
        guard let otherSection = memoSections.first(where: { $0.id == FloorPlanMemoSectionID.unassigned }) else {
            return roomRows
        }
        return roomRows + [
            CaseSidebarRow(
                name: otherSection.locationName,
                systemImage: "mappin.and.ellipse",
                count: otherSection.memos.count
            )
        ]
    }
    
    // 장소 이름에 맞는 사이드바 아이콘
    // TEMP: 장소 종류 데이터가 없어 이름으로 고름 — Room에 종류가 생기면 그것으로 바꿈
    private static func systemImage(forRoom name: String) -> String {
        if name.contains("거실") { return "lamp.floor" }
        if name.contains("주방") || name.contains("부엌") { return "fork.knife" }
        if name.contains("욕실") || name.contains("화장실") { return "shower" }
        if name.contains("방") || name.contains("침실") { return "bed.double" }
        return "square.dashed"
    }
    
    // 앨범의 "위치 미지정 >": 도면 탭 2D로 가서 오른쪽에 위치 미확인 사진 패널을 연다
    private func showPhotoPlacement() {
        selection = .floorPlan2D
        withAnimation {
            isPlacingPhotos = true
        }
    }
    
    // 상단의 "메모 추가"를 누르면 2D 도면으로 이동하고 위치 선택 모드를 시작한다.
    private func beginAddingMemo() {
        selection = .floorPlan2D
        isPlacingPhotos = false
        memoDraft = nil
        floorPlanPresentationID = UUID()
        withAnimation {
            isAddingMemo = true
        }
    }
    
    // 위치 선택이나 입력 중에 작성을 취소한다.
    private func cancelAddingMemo() {
        withAnimation {
            isAddingMemo = false
            memoDraft = nil
        }
    }
    
    // 작성을 완료한 메모를 장소별 목록에 추가하고 현재 도면을 유지한다.
    private func addMemo(_ draft: FloorPlanMemoDraft) {
        let number = memoSections.allMemos.count + 1
        let memo = FloorPlanMemo(
            title: "메모 #\(number)",
            content: draft.content,
            locationID: draft.locationID,
            locationName: draft.locationName,
            anchor: draft.anchor
        )
        memoSections.append(memo)
        updateMemoCount()
        isAddingMemo = false
        memoDraft = nil
    }
    
    // 사건 미리보기에서도 방금 작성한 메모 개수가 보이도록 맞춘다.
    private func updateMemoCount() {
        fireCase.memoCount = memoSections.allMemos.count
    }
    
    // 탭마다 상단 바가 따로 있어서, 어느 탭에서든 같은 상단 바 버튼이 보이도록 각 탭 내용에 붙인다
    private func withCaseToolbars(_ content: some View) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .caseActionToolbar(
                onAddMemo: {
                    beginAddingMemo()
                },
                onTakePhoto: takePhoto,
                onImportPhoto: importPhoto,
                onEdit: onEdit,
                onExport: {
                    isExportSheetPresented = true
                }
            )
    }

    /// 사이드바를 접었을 때 왼쪽 위의 뒤로가기·사건명·조사 차수. 시스템 상단 바 왼쪽 칸이 사라지는 일이 있어 탭 위에 직접 겹친다
    private var titleHeader: some View {
        CaseTitleHeader(
            title: fireCase.title,
            sessionNumber: sessionNumber,
            sessionNumbers: fireCase.sessionNumbers,
            onSelectSession: { number in
                sessionNumber = number
            },
            onAddSession: addSession,
            onBack: onBack
        )
    }
    
    /// 가장 큰 차수 다음 번호로 새 차수를 만들고 그 차수를 고른다
    private func addSession() {
        sessionNumber = fireCase.addSession()
    }
    
    /// 사이드바에서 삭제를 확인한 장소의 사진·메모를 비운다. 장소 줄은 남고 개수만 0이 된다
    private func clearRow(_ value: CaseTabSelection) {
        switch value {
        case .album(let name):
            // 위치 미지정 줄이면 장소가 없는(nil) 사진을 지운다
            let roomKey = planData.rooms.first { $0.name == name }?.id
            guard roomKey != nil || name == CaseAlbumView.unassignedName else { return }
            photoStore.deleteAll(inRoom: roomKey)
        case .memo(let name):
            guard let index = memoSections.firstIndex(where: { $0.locationName == name }) else { return }
            memoSections[index].memos.removeAll()
            updateMemoCount()
        case .floorPlan2D, .floorPlan3D, .albumOverview:
            // 도면 줄과 앨범 전체는 지울 수 없다
            return
        }
    }
    
    /// "사진 촬영하기": 카메라, 그다음 위치 권한을 확인한다. 위치는 촬영 위치를 남기는 데 필요해서 거절하면 촬영하지 않는다
    // TEMP: 앞 단계 권한 화면 코드가 생기면 '이전에 물었는지'에 따른 분기 추가 필요
    private func takePhoto() {
        Task {
            guard checkAllowed(await PermissionService.requestCameraPermission(), deniedPermission: .camera) else { return }
            guard checkAllowed(await PermissionService.requestLocationPermission(), deniedPermission: .location) else { return }
            isCapturingPhoto = true
        }
    }
    
    /// "사진 불러오기": 사진 보관함 권한을 확인한다
    // TEMP: 앞 단계 권한 화면 코드가 생기면 '이전에 물었는지'에 따른 분기 추가 필요
    private func importPhoto() {
        Task {
            guard checkAllowed(await PermissionService.requestPhotoLibraryPermission(), deniedPermission: .photoLibrary) else { return }
            isImportingPhoto = true
        }
    }
    
    /// 허용이면 true. 방금 알림에서 거절했으면 메인에 그대로 두고(Figma 권한 거부 화면),
    /// 전에 이미 거절했으면 다시 물을 수 없으므로 설정 이동 알림을 띄운다
    private func checkAllowed(_ result: PermissionService.Result, deniedPermission permission: DeniedPermission) -> Bool {
        switch result {
        case .allowed:
            return true
        case .deniedNow:
            return false
        case .deniedBefore:
            deniedPermission = permission
            return false
        }
    }
    
    /// 설정 이동 알림은 deniedPermission에 값이 있을 때 뜨고, 닫히면 값을 지운다
    private var isDeniedAlertShown: Binding<Bool> {
        Binding(
            get: { deniedPermission != nil },
            set: { isShown in
                if !isShown { deniedPermission = nil }
            }
        )
    }
    
    /// 아직 내용이 없는 앨범·메모 탭의 빈 화면
    private func emptyTab(_ placeholder: String) -> some View {
        Text(placeholder)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.quaternary)
    }
}

// 문구
extension CaseMainView {
    private enum Copy {
        // TEMP: 메모 데이터가 생기기 전 임시 값 — 데이터가 생기면 장소별 개수로 바꿔야 함
        // name은 ERD Room.name. count는 ERD에 없는 계산값으로 memoCount라는 이름으로 쓸 예정 (임시 이름, PR에 명시)
        static let memoRows = [
            CaseSidebarRow(name: "발화지점", systemImage: "flame", count: 3),
            CaseSidebarRow(name: "거실", systemImage: "lamp.floor", count: 5),
            CaseSidebarRow(name: "안방", systemImage: "bed.double", count: 2),
            CaseSidebarRow(name: "방1", systemImage: "fork.knife", count: 6)
        ]
        
        static let memoPlaceholder = "메모 자리"
        
        // 거절 알림 (Figma "사진 접근이 필요해요")
        static let openSettings = "설정 열기"
        static let cancel = "취소"
        static let photoLibraryDeniedTitle = "사진 접근이 필요해요"
        static let photoLibraryDeniedMessage = "사진을 가져오려면 사진 보관함 접근을 허용해주세요. 설정에서 개인정보 보호 및 보안 > 사진 > FIRELINE을 선택해 접근을 허용할 수 있어요."
        // TEMP: Figma의 카메라 알림은 공간 스캔 문구라 사진 촬영에 맞게 고쳐 씀. 위치 알림은 Figma에 없어 같은 형식으로 작성 — 팀 확정 필요
        static let cameraDeniedTitle = "카메라 접근이 필요해요"
        static let cameraDeniedMessage = "사진을 촬영하려면 카메라 접근을 허용해주세요. 설정에서 개인정보 보호 및 보안 > 카메라 > FIRELINE을 선택해 접근을 허용할 수 있어요."
        static let locationDeniedTitle = "위치 접근이 필요해요"
        static let locationDeniedMessage = "사진의 촬영 위치를 남기려면 위치 접근을 허용해주세요. 설정에서 개인정보 보호 및 보안 > 위치 서비스 > FIRELINE을 선택해 접근을 허용할 수 있어요."
    }
    
    /// 거절돼서 설정 앱으로 안내해야 하는 권한과 그 알림 문구
    private enum DeniedPermission {
        case camera
        case photoLibrary
        case location
        
        var title: String {
            switch self {
            case .camera: Copy.cameraDeniedTitle
            case .photoLibrary: Copy.photoLibraryDeniedTitle
            case .location: Copy.locationDeniedTitle
            }
        }
        
        var message: String {
            switch self {
            case .camera: Copy.cameraDeniedMessage
            case .photoLibrary: Copy.photoLibraryDeniedMessage
            case .location: Copy.locationDeniedMessage
            }
        }
    }
}

#Preview {
    CaseMainView(
        fireCase: FireCase(address: "서울시 강남구 청암로 77", occurredAt: .now),
        planData: DummyFloorPlan.planData,
        photoStore: PhotoStore(),
        onBack: {},
        onEdit: {}
    )
    .modelContainer(for: FireCase.self, inMemory: true)
}

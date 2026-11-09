// 사건 작업 메인 화면. 상단 바와 도면·앨범·메모 탭으로 구성된다

import SwiftData
import SwiftUI

/// 도면·앨범·메모를 오가며 사건을 작업하는 화면
struct CaseMainView: View {
    /// 작업 중인 사건. 상단 바의 사건명·조사 차수를 여기서 읽는다
    let fireCase: FireCase
    // 뒤로가기, 편집하기(펜 아이콘)
    let onBack: () -> Void
    let onEdit: () -> Void
    /// 도면 탭에 보여 줄 도면
    let planData: PlanData
    
    // 탭을 오가도 고른 값이 남도록 탭이 아니라 이 화면이 기억한다
    @State private var photoFilter = PhotoFilter()
    // 사이드바에서 고른 줄. 도면의 2D·3D도 여기서 정해진다
    @State private var selection = CaseTabSelection.floorPlan2D
    // 사이드바의 장소 줄. 삭제하면 개수가 0이 되도록 화면이 들고 있는다
    @State private var albumRows = Copy.albumRows
    @State private var memoRows = Copy.memoRows
    // 거절된 권한. 값이 있으면 설정 앱으로 안내하는 알림이 뜬다
    @State private var deniedPermission: DeniedPermission?
    @State private var isExportSheetPresented = false
    /// 상단 바에서 고른 조사 차수. 처음에는 가장 최근 차수
    @State private var sessionNumber: Int

    init(fireCase: FireCase, onBack: @escaping () -> Void, onEdit: @escaping () -> Void, planData: PlanData) {
        self.fireCase = fireCase
        self.onBack = onBack
        self.onEdit = onEdit
        self.planData = planData
        _sessionNumber = State(initialValue: fireCase.sessions.map(\.sessionNumber).max() ?? 1)
    }

    var body: some View {
        CaseTabView(selection: $selection, albumRows: albumRows, memoRows: memoRows, onClearRow: clearRow) {
            withCaseToolbars(FloorPlanTabView(photoFilter: $photoFilter, dimension: dimension, planData: planData))
        } album: {
            withCaseToolbars(emptyTab(Copy.albumPlaceholder))
        } memo: {
            withCaseToolbars(emptyTab(Copy.memoPlaceholder))
        }
        .onAppear(perform: addFirstSessionIfNeeded)
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
    
    /// 탭마다 상단 바가 따로 있어서, 어느 탭에서든 같은 상단 바 버튼이 보이도록 각 탭 내용에 붙인다
    private func withCaseToolbars(_ content: some View) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .caseActionToolbar(
                onAddMemo: {
                    // TODO: 메모 추가
                },
                onTakePhoto: takePhoto,
                onImportPhoto: importPhoto,
                onEdit: onEdit,
                onExport: {
                    isExportSheetPresented = true
                }
            )
            .caseTitleToolbar(
                title: fireCase.title,
                sessionNumber: sessionNumber,
                sessionNumbers: sessionNumbers,
                onSelectSession: { number in
                    // TODO: 차수별 사진이 생기면 고른 차수의 사진만 보이게
                    sessionNumber = number
                },
                onAddSession: addSession
            )
        // 나중에 붙인 toolbar의 버튼이 앞에 놓이므로, 뒤로가기가 맨 왼쪽에 오도록 backOnlyToolbar를 마지막에 붙인다
            .backOnlyToolbar(onBack: onBack)
    }
    
    /// 사건의 조사 차수를 1차부터 차례로
    private var sessionNumbers: [Int] {
        fireCase.sessions.map(\.sessionNumber).sorted()
    }

    /// 가장 큰 차수 다음 번호로 새 차수를 만들고 그 차수를 고른다
    private func addSession() {
        let nextNumber = (sessionNumbers.last ?? 0) + 1
        fireCase.sessions.append(InvestigationSession(sessionNumber: nextNumber))
        sessionNumber = nextNumber
    }

    /// 차수가 하나도 없는 사건이면 1차를 만든다
    // TEMP: 사건 등록 때 1차를 만들지 않아서 여기서 만듦 — 등록 화면에서 1차를 만들게 되면 지움
    private func addFirstSessionIfNeeded() {
        guard fireCase.sessions.isEmpty else { return }
        addSession()
    }

    /// 사이드바에서 삭제를 확인한 장소의 사진·메모를 비운다. 장소 줄은 남고 개수만 0이 된다
    private func clearRow(_ value: CaseTabSelection) {
        switch value {
        case .album(let name):
            // TODO: 이 장소의 사진(EvidencePhoto)을 실제로 지우기 — 사진 데이터가 생기면
            guard let index = albumRows.firstIndex(where: { $0.name == name }) else { return }
            albumRows[index].count = 0
        case .memo(let name):
            // TODO: 이 장소의 메모를 실제로 지우기 — 메모 데이터가 생기면
            guard let index = memoRows.firstIndex(where: { $0.name == name }) else { return }
            memoRows[index].count = 0
        case .floorPlan2D, .floorPlan3D:
            // 도면 줄은 지울 수 없다
            return
        }
    }
    
    /// "사진 촬영하기": 카메라, 그다음 위치 권한을 확인한다. 위치는 촬영 위치를 남기는 데 필요해서 거절하면 촬영하지 않는다
    // TEMP: 앞 단계 권한 화면 코드가 생기면 '이전에 물었는지'에 따른 분기 추가 필요
    private func takePhoto() {
        Task {
            guard checkAllowed(await PermissionService.requestCameraPermission(), deniedPermission: .camera) else { return }
            guard checkAllowed(await PermissionService.requestLocationPermission(), deniedPermission: .location) else { return }
            // TODO: 사진 촬영 화면 띄우기 (Figma 17:5114~, 이후 묶음)
        }
    }
    
    /// "사진 불러오기": 사진 보관함 권한을 확인한다
    // TEMP: 앞 단계 권한 화면 코드가 생기면 '이전에 물었는지'에 따른 분기 추가 필요
    private func importPhoto() {
        Task {
            guard checkAllowed(await PermissionService.requestPhotoLibraryPermission(), deniedPermission: .photoLibrary) else { return }
            // TODO: 사진 선택 화면 띄우기 (Figma 17:4837 "사진" 시트, 이후 묶음)
        }
    }
    
    /// 허용이면 true. 방금 알림에서 거절했으면 메인에 그대로 두고(Figma 40:35726),
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
        // TEMP: 장소·사진·메모 데이터가 생기기 전 임시 값 — 데이터가 생기면 장소별 개수로 바꿔야 함
        // name은 ERD Room.name. count는 ERD에 없는 계산값으로, 앨범은 evidencePhotoCount, 메모는 memoCount라는 이름으로 쓸 예정 (임시 이름, PR에 명시)
        static let albumRows = [
            CaseSidebarRow(name: "위치 미지정", systemImage: "photo.badge.exclamationmark", count: 120),
            CaseSidebarRow(name: "거실", systemImage: "lamp.floor", count: 89),
            CaseSidebarRow(name: "안방", systemImage: "bed.double", count: 42),
            CaseSidebarRow(name: "주방", systemImage: "fork.knife", count: 83)
        ]
        static let memoRows = [
            CaseSidebarRow(name: "발화지점", systemImage: "flame", count: 3),
            CaseSidebarRow(name: "거실", systemImage: "lamp.floor", count: 5),
            CaseSidebarRow(name: "안방", systemImage: "bed.double", count: 2),
            CaseSidebarRow(name: "방1", systemImage: "fork.knife", count: 6)
        ]
        
        static let albumPlaceholder = "앨범 자리"
        static let memoPlaceholder = "메모 자리"
        
        // TEMP: Figma에 거절 알림이 없어 임의로 작성한 문구 — 팀 확정 필요
        static let openSettings = "설정으로 이동"
        static let cancel = "취소"
        static let cameraDeniedTitle = "카메라 접근이 꺼져 있습니다"
        static let cameraDeniedMessage = "사진을 촬영하려면 설정에서 카메라 접근을 허용해 주세요."
        static let photoLibraryDeniedTitle = "사진 접근이 꺼져 있습니다"
        static let photoLibraryDeniedMessage = "사진을 불러오려면 설정에서 사진 접근을 허용해 주세요."
        static let locationDeniedTitle = "위치 접근이 꺼져 있습니다"
        static let locationDeniedMessage = "사진의 촬영 위치를 남기려면 설정에서 위치 접근을 허용해 주세요."
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
        onBack: {},
        onEdit: {},
        planData: DummyFloorPlan.planData
    )
    .modelContainer(for: FireCase.self, inMemory: true)
}

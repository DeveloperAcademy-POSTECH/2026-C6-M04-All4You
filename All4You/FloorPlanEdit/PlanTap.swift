// 2D·3D 수정 화면에서 누른 곳과, 도면을 바꾼 것. 화면 상태라 저장하지 않는다

/// 누른 곳을 도면 기준 값으로 바꾼 것
enum PlanTap {
    /// 고를 수 있는 요소 (스탬프·콘센트·창문)
    case element(PlanSelection)
    /// 바닥 위 도면 점 (m)
    case floor(SIMD2<Double>)
    /// 벽 면 위 도면 점 (m)과 바닥에서 높이 (m)
    case wall(id: String, point: SIMD2<Double>, height: Double)
}

/// 스탬프를 바꾼 것. 끌기는 손을 뗄 때 한 번 알린다
enum PlanEdit {
    /// 스탬프를 도면 점 (m)과 바닥에서 높이 (m)로 옮김. 사람·발화지점은 높이를 쓰지 않는다
    case move(PlanSelection, point: SIMD2<Double>, height: Double)
    /// 사람·발화지점(PlanMarker.id)의 방향을 yaw(도)로 바꿈
    case rotate(markerId: String, yaw: Double)
    /// 스탬프를 옆에 하나 더 만듦
    case duplicate(PlanSelection)
    /// 스탬프·창문을 지움
    case delete(PlanSelection)
    /// 창문(DoorWindow.id) 테두리 edge를 벽 시작점에서 along(m), 바닥에서 height(m) 자리로 옮김
    case resizeWindow(id: String, edge: WindowEdge, along: Double, height: Double)
}

// 바꾼 것을 도면에 반영하기
extension PlanData {
    /// 옮기거나 돌리거나 복제·삭제한 것을 도면에 반영하고, 그 뒤 고를 것을 돌려준다.
    /// 복제하면 새 것을, 지우면 nil을, 나머지는 selection을 그대로 돌려준다
    mutating func apply(_ edit: PlanEdit, selection: PlanSelection?) -> PlanSelection? {
        switch edit {
        case .duplicate(.marker(let id)):
            return duplicateMarker(id: id).map(PlanSelection.marker) ?? selection
        case .duplicate(.wallFixture(let id)):
            return duplicateWallFixture(id: id).map(PlanSelection.wallFixture) ?? selection
        case .duplicate(.doorWindow):
            return selection
        case .delete(.marker(let id)):
            removeMarker(id: id)
            return nil
        case .delete(.wallFixture(let id)):
            removeWallFixture(id: id)
            return nil
        case .delete(.doorWindow(let id)):
            removeDoorWindow(id: id)
            return nil
        case .resizeWindow(let id, let edge, let along, let height):
            resizeWindow(id: id, edge: edge, along: along, height: height)
        case .move(.marker(let id), let point, _):
            moveMarker(id: id, to: point)
        case .move(.wallFixture(let id), let point, let height):
            moveWallFixture(id: id, to: point, height: height)
        case .move(.doorWindow, _, _):
            break
        case .rotate(let markerId, let yaw):
            rotateMarker(id: markerId, yaw: yaw)
        }
        return selection
    }
}

// 도구로 빈 곳을 눌러 놓기, 고른 스탬프 옮기기
extension PlanData {
    /// 고른 스탬프를 도면 점 point로 옮긴다. 벽에 붙은 것은 붙은 벽을 따라서만 움직이고 높이는 그대로 둔다
    mutating func moveStamp(_ selection: PlanSelection, to point: SIMD2<Double>) {
        switch selection {
        case .marker(let id):
            moveMarker(id: id, to: point)
        case .wallFixture(let id):
            guard let height = wallFixtures.first(where: { $0.id == id })?.heightFromFloor else { return }
            moveWallFixture(id: id, to: point, height: height)
        case .doorWindow:
            break
        }
    }

    /// 고른 도구에 맞는 자리(발화지점·피해자는 바닥, 전기·창문은 벽)를 눌렀으면 놓고, 새로 놓은 것을 돌려준다.
    /// 맞지 않는 자리이거나 놓을 수 없으면 아무것도 바꾸지 않고 nil
    mutating func place(_ tool: EditTool, at tap: PlanTap) -> PlanSelection? {
        switch (tool, tap) {
        case (.ignitionPoint, .floor(let point)):
            return addMarker(.ignitionPoint, at: point).map(PlanSelection.marker)
        case (.person, .floor(let point)):
            return addMarker(.person, at: point).map(PlanSelection.marker)
        case (.outlet, .wall(let wallId, let point, let height)):
            return addWallFixture(.outlet, wallId: wallId, at: point, height: height).map(PlanSelection.wallFixture)
        case (.window, .wall(let wallId, let point, _)):
            return addWindow(wallId: wallId, at: point).map(PlanSelection.doorWindow)
        default:
            return nil
        }
    }
}

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
    /// 사람·발화지점(PlanMarker.id)의 크기 배율을 scale로 바꿈
    case resize(markerId: String, scale: Double)
    /// 가구(Furniture.id)의 방향을 rotation(라디안)으로 바꿈
    case rotateFurniture(id: String, rotation: Double)
    /// 스탬프를 옆에 하나 더 만듦
    case duplicate(PlanSelection)
    /// 스탬프·창문을 지움
    case delete(PlanSelection)
    /// 가구(Furniture.id)의 가로·세로(m)를 바꿈. 원형은 width만 씀
    case resizeFurniture(id: String, width: Double, depth: Double)
    /// 가구(Furniture.id)를 바닥에서 elevation(m)만큼 띄움
    case elevateFurniture(id: String, elevation: Double)
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
        case .duplicate(.doorWindow), .duplicate(.wall), .duplicate(.furniture):
            return selection
        case .delete(.furniture(let id)):
            removeFurniture(id: id)
            return nil
        case .move(.furniture(let id), let point, _):
            moveFurniture(id: id, to: point)
        case .rotateFurniture(let id, let rotation):
            rotateFurniture(id: id, rotation: rotation)
        case .resizeFurniture(let id, let width, let depth):
            resizeFurniture(id: id, width: width, depth: depth)
        case .elevateFurniture(let id, let elevation):
            elevateFurniture(id: id, to: elevation)
        case .delete(.wall(let id)):
            removeWall(id: id)
            return nil
        case .move(.wall, _, _):
            break
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
        case .resize(let markerId, let scale):
            resizeMarker(id: markerId, scale: scale)
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
        case .furniture(let id):
            moveFurniture(id: id, to: point)
        case .doorWindow, .wall:
            break
        }
    }

    /// 고른 도구에 맞는 자리(발화지점·피해자는 바닥, 전기·창문·문은 벽)를 눌렀으면 놓고, 새로 놓은 것을 돌려준다.
    /// 맞지 않는 자리이거나 놓을 수 없으면 아무것도 바꾸지 않고 nil
    mutating func place(_ tool: EditTool, at tap: PlanTap, defaults: StampDefaults? = nil) -> PlanSelection? {
        switch (tool, tap) {
        case (.ignitionPoint, .floor(let point)):
            return addMarker(.ignitionPoint, at: point, scale: defaults?.markerScale(.ignitionPoint)).map(PlanSelection.marker)
        case (.person, .floor(let point)):
            return addMarker(.person, at: point, scale: defaults?.markerScale(.person)).map(PlanSelection.marker)
        case (.outlet, .wall(let wallId, let point, let height)):
            return addWallFixture(.outlet, wallId: wallId, at: point, height: height).map(PlanSelection.wallFixture)
        case (.outlet, .floor(let point)):
            // 전기는 벽 외에 바닥에도 놓을 수 있다 (멀티탭·바닥 콘센트). 바닥에 놓은 것은 사람·발화지점처럼 markers에 넣는다
            return addMarker(.outlet, at: point, scale: defaults?.markerScale(.outlet)).map(PlanSelection.marker)
        case (.window, .wall(let wallId, let point, _)):
            return addOpening(.window, wallId: wallId, at: point, width: defaults?.windowWidth).map(PlanSelection.doorWindow)
        case (.door, .wall(let wallId, let point, _)):
            return addOpening(.door, wallId: wallId, at: point, width: defaults?.doorWidth).map(PlanSelection.doorWindow)
        default:
            return nil
        }
    }
}

// 놓지 못한 이유
extension PlanData {
    /// 도구로 tap 자리에 스탬프를 놓지 못했을 때, 어디에 어떻게 놓으면 되는지 알려 주는 문장.
    /// 눌렀다가 놓이지 않은 자리만 다룬다 (place가 nil을 돌려준 경우)
    func placementHint(for tool: EditTool, at tap: PlanTap) -> String {
        switch (tool, tap) {
        case (.ignitionPoint, .floor(let point)), (.person, .floor(let point)), (.outlet, .floor(let point)):
            if !isInsideRoom(point) {
                return "\(tool.title)는 방 안쪽 바닥에만 놓을 수 있어요. 벽으로 둘러싸인 방 안을 눌러 주세요"
            }
            if tool == .person {
                return "피해자는 몸이 길어서 벽에서 1m쯤 떨어진 곳에만 놓을 수 있어요. 방 가운데쪽 빈 바닥을 눌러 주세요"
            }
            return "벽에 너무 가까워요. 벽에서 조금 떨어진 방 안쪽 바닥을 눌러 주세요"
        case (.ignitionPoint, _), (.person, _):
            return "\(tool.title)는 벽이 아니라 바닥에 놓아요. 방 안쪽 바닥을 눌러 주세요"
        case (.outlet, _):
            return "전기는 방 안쪽을 향한 벽 면에만 붙일 수 있어요. 건물 바깥쪽이 아니라 방 안쪽에서 벽을 눌러 주세요"
        case (.window, .wall), (.door, .wall):
            return "벽에 \(tool.title)을 달 빈 자리가 부족해요. 문·창문이 없는 더 긴 벽 구간을 눌러 주세요"
        case (.window, _), (.door, _):
            return "\(tool.title)은 벽에만 달 수 있어요. 벽을 눌러 주세요"
        default:
            return "이 도구는 이 자리에 쓸 수 없어요. 다른 자리를 눌러 주세요"
        }
    }
}

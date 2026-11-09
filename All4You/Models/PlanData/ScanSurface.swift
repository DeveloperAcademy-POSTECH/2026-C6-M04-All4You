// 공간 스캔(RoomPlan) 결과에서 도면으로 바꾸는 데 필요한 값만 옮긴 중간 형식. 저장하지 않는다
// RoomPlan 결과는 LiDAR 실기기에서만 만들어지므로, 변환은 이 형식만 받게 해서 손으로 만든 값으로도 확인할 수 있게 한다
// 좌표는 스캔한 AR 세션의 월드 좌표 (m, +y = 위). 바닥면은 (x, z)

import Foundation

/// 스캔한 면 하나 (벽·문·창문·개구부·바닥). 위치는 면의 가운데
struct ScanSurface {
    enum Kind {
        case wall, door, window, opening, floor
    }

    let id: UUID
    let kind: Kind
    /// 면 가운데 (x, y, z)
    let center: SIMD3<Double>
    /// 바닥면에서 본 폭 방향 (x, z), 길이 1
    let widthAxis: SIMD2<Double>
    /// 폭·높이 (m)
    let width: Double
    let height: Double
    /// 문·창문·개구부가 붙은 벽의 id
    let parentId: UUID?
}

/// 스캔이 알아본 물체 하나 (침대·의자 …). 위치는 상자 가운데
struct ScanObject {
    /// 물체 종류 (RoomPlan 영어 이름, 예: "refrigerator")
    let category: String
    /// 상자 가운데 (x, y, z)
    let center: SIMD3<Double>
    /// 바닥면에서 본 가로 방향 (x, z), 길이 1
    let widthAxis: SIMD2<Double>
    /// 가로·높이·세로 (m)
    let width: Double
    let height: Double
    let depth: Double
}

/// 스캔이 알아본 방 종류와 그 방의 가운데 점. 방 경계는 주지 않는다
struct ScanSection {
    /// 방 이름으로 쓸 종류 (침실, 거실 …). 알아보지 못한 방은 nil
    let name: String?
    /// 가운데 점 (x, y, z)
    let center: SIMD3<Double>
}

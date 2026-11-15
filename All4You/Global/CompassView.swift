// 도면 방위표. 숫자 4 모양의 선(세로 북-남 선, 가로 서-동 선, 서쪽에서 북쪽으로 올라가는 사선)에
// N·E·S·W를 붙여, 지금 보는 도면에서 북쪽이 어느 쪽인지 알려 준다
// 2D·3D 수정 화면과 메인 도면 탭이 쓰고, 내보내기도 같이 쓸 수 있게 Global에 둔다.
// 2D 수정 화면에서는 방위표를 끌어 돌려 북쪽을 원하는 방향으로 정한다 (도면은 돌지 않는다)

import SwiftUI

/// 4 모양 방위표. 북쪽(N)이 4의 꼭대기다
struct CompassView: View {
    /// 화면 위쪽에서 북쪽까지 시계 방향으로 잰 각. 2D는 도면에 정해 둔 북쪽 각(PlanData.northAngle), 3D는 거기에 카메라가 도는 만큼 더해진다
    var northAngle: Angle = .zero
    /// 방위표를 끄는 동안 새 북쪽 각을 계속 알린다. nil이면 돌릴 수 없는 방위표다
    var onRotate: ((Angle) -> Void)? = nil
    /// 손을 떼면 마지막 북쪽 각을 한 번 알린다 (도면에 저장하는 때)
    var onRotateEnd: ((Angle) -> Void)? = nil

    /// 끌기를 시작한 순간의 손가락 각과 북쪽 각. 손가락이 돈 만큼 북쪽도 돌리려고 기억한다
    @State private var dragStart: (touch: Angle, north: Angle)?

    var body: some View {
        // 선과 글자는 가로·세로 선이 만나는 점을 중심으로 함께 돌고, 글자만 반대로 돌아 늘 바로 서 있다
        ZStack {
            CompassFour()
                .stroke(Color.gray700, style: StrokeStyle(lineWidth: Layout.lineWidth, lineCap: .round, lineJoin: .round))
                .frame(width: Layout.frameSize, height: Layout.frameSize)
            letter("N", color: Color.brand500, x: 0, y: -(Layout.arm + Layout.letterGap))
            letter("S", color: .black, x: 0, y: Layout.arm + Layout.letterGap)
            letter("W", color: .black, x: -(Layout.arm + Layout.letterGap), y: 0)
            letter("E", color: .black, x: Layout.arm + Layout.letterGap, y: 0)
        }
        .rotationEffect(northAngle)
        .frame(width: Layout.frameSize, height: Layout.frameSize)
        // 그려진 선·글자 밖의 빈 곳을 눌러도 돌릴 수 있게 네모 전체를 누르는 자리로 한다
        .contentShape(Rectangle())
        .gesture(rotateGesture, isEnabled: onRotate != nil)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Copy.accessibility)
        .accessibilityValue(Copy.accessibilityValue(degrees: northAngle.degrees))
        .accessibilityAdjustableAction { direction in
            guard onRotate != nil else { return }
            let step = Angle.degrees(direction == .increment ? Layout.accessibilityStep : -Layout.accessibilityStep)
            onRotateEnd?(Self.normalized(northAngle + step))
        }
    }

    private func letter(_ text: String, color: Color, x: CGFloat, y: CGFloat) -> some View {
        Text(text)
            .font(AppTypography.subheadlineEmphasized)
            .foregroundStyle(color)
            .rotationEffect(-northAngle)
            .offset(x: x, y: y)
    }
}

// 돌리기
extension CompassView {
    /// 방위표 위에서 손가락이 도는 만큼 북쪽을 돌린다. 방위표 가운데에서 손가락까지의 방향이 바뀐 만큼 더한다
    private var rotateGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let touch = touchAngle(at: value.location)
                if dragStart == nil { dragStart = (touch, northAngle) }
                guard let start = dragStart else { return }
                onRotate?(Self.normalized(start.north + (touch - start.touch)))
            }
            .onEnded { value in
                guard let start = dragStart else { return }
                onRotateEnd?(Self.normalized(start.north + (touchAngle(at: value.location) - start.touch)))
                dragStart = nil
            }
    }

    /// 방위표 가운데에서 본 손가락 방향. 위쪽이 0이고 시계 방향으로 커진다
    private func touchAngle(at point: CGPoint) -> Angle {
        let center = Layout.frameSize / 2
        return .radians(atan2(point.x - center, center - point.y))
    }

    /// 각을 -180°~180° 안으로 줄인다. 여러 바퀴를 돌려도 값이 커지지 않게 한다
    private static func normalized(_ angle: Angle) -> Angle {
        .radians(atan2(sin(angle.radians), cos(angle.radians)))
    }
}

/// 숫자 4 모양 선. 가로·세로 선이 만나는 점이 이 뷰의 가운데다
private struct CompassFour: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let top = CGPoint(x: center.x, y: center.y - Layout.arm)
        let bottom = CGPoint(x: center.x, y: center.y + Layout.arm)
        let west = CGPoint(x: center.x - Layout.arm, y: center.y)
        let east = CGPoint(x: center.x + Layout.arm, y: center.y)
        return Path { path in
            // 세로 선: 남 → 북
            path.move(to: bottom)
            path.addLine(to: top)
            // 사선: 북 → 서
            path.addLine(to: west)
            // 가로 선: 서 → 동
            path.addLine(to: east)
        }
    }
}

// 레이아웃 값 (pt). 4의 모양은 가운데(가로·세로 선이 만나는 점)에서 네 끝까지 같은 길이로 정한다
private enum Layout {
    /// 동·서·남·북 모두 같은 길이
    static let arm: CGFloat = 30
    /// 선 끝에서 글자 가운데까지
    static let letterGap: CGFloat = 12
    static let lineWidth: CGFloat = 2
    /// 어느 쪽으로 돌아도 글자가 잘리지 않을 정사각형 크기
    static let frameSize: CGFloat = 104
    /// 보이스오버로 한 번 조절할 때 돌리는 각 (도)
    static let accessibilityStep = 15.0
}

// 문구
extension CompassView {
    private enum Copy {
        // TEMP: Figma에 없는 방위표라 모양·문구를 임의로 정함 — 디자인 확인 필요
        static let accessibility = "방위표"

        static func accessibilityValue(degrees: Double) -> String {
            // NaN·무한대는 Int로 바꾸면 앱이 멈추므로 돌리지 않은 것으로 읽는다
            guard degrees.isFinite else { return "북쪽이 위쪽" }
            // 여러 바퀴 돈 값도 한 바퀴 안의 각으로 줄여 읽는다
            let rounded = Int(degrees.truncatingRemainder(dividingBy: 360).rounded())
            return rounded == 0 ? "북쪽이 위쪽" : "북쪽이 위쪽에서 시계 방향으로 \(rounded)도"
        }
    }
}

#Preview {
    @Previewable @State var north = Angle.zero
    HStack(spacing: 24) {
        CompassView()
        CompassView(northAngle: .degrees(40))
        CompassView(northAngle: .degrees(180))
        CompassView(northAngle: north, onRotate: { north = $0 }, onRotateEnd: { north = $0 })
    }
    .padding()
}

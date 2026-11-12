// 도면 방위표. 숫자 4 모양의 선(세로 북-남 선, 가로 서-동 선, 서쪽에서 북쪽으로 올라가는 사선)에
// N·E·S·W를 붙여, 지금 보는 도면에서 북쪽이 어느 쪽인지 알려 준다
// 2D·3D 수정 화면이 쓰고, 메인 도면 탭과 내보내기도 같이 쓸 수 있게 Global에 둔다

import SwiftUI

/// 4 모양 방위표. 북쪽(N)이 4의 꼭대기다
struct CompassView: View {
    /// 화면 위쪽에서 북쪽까지 시계 방향으로 잰 각. 2D는 늘 0(도면 위쪽이 북쪽), 3D는 카메라가 도는 만큼 바뀐다
    var northAngle: Angle = .zero

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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Copy.accessibility)
    }

    private func letter(_ text: String, color: Color, x: CGFloat, y: CGFloat) -> some View {
        Text(text)
            .font(AppTypography.subheadlineEmphasized)
            .foregroundStyle(color)
            .rotationEffect(-northAngle)
            .offset(x: x, y: y)
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
}

// 문구
extension CompassView {
    private enum Copy {
        // TEMP: Figma에 없는 방위표라 모양·문구를 임의로 정함 — 디자인 확인 필요
        static let accessibility = "방위표, 북쪽이 위쪽 기준"
    }
}

#Preview {
    HStack(spacing: 24) {
        CompassView()
        CompassView(northAngle: .degrees(40))
        CompassView(northAngle: .degrees(180))
    }
    .padding()
}

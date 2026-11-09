//
//  CasePlan2DView.swift
//  All4You
//
//  Created by SIA on 11/9/26.
//

// 사건 작업 메인의 2D 도면. 벽·스탬프·장소를 그리고, 장소마다 사진 핀(대표 사진·장 수)을 띄운다.
// 위치 미확인 사진을 끌어다 놓으면 놓은 자리의 장소를 알려 준다 (장소 찾기는 PlanData+Inside의 room(containing:))
// TEMP: 2D 도면 그리기가 아직 없어 벽 선·스탬프 기호만 그림 — 2D 도면 수정 화면의 그리기가 생기면 그것으로 바꿈

import SwiftUI

/// 도면 위 한 장소의 사진 핀. 그 장소의 대표 사진과 사진 수
struct RoomPhotoPin {
    let thumbnail: UIImage
    let count: Int
}

/// 도면을 화면에 맞춰 그리고, 장소 핀·라벨을 장소의 라벨 자리에 띄운다
struct CasePlan2DView: View {
    let planData: PlanData
    /// 장소(Room.id)별 사진 핀. 없는 장소는 이름만 보인다
    let pins: [String: RoomPhotoPin]
    /// 사진을 끌어다 놓는 중이라 장소 이름을 흐리게 보여 줄지
    var isPlacingPhotos = false
    /// 사진 핀을 누르면 그 장소를 알린다
    let onTapRoom: (Room) -> Void
    /// 사진(EvidencePhoto.id)을 장소 위에 놓으면 알린다
    var onDropPhoto: (UUID, Room) -> Void = { _, _ in }

    var body: some View {
        GeometryReader { proxy in
            let fit = PlanFit(planData: planData, size: proxy.size)
            ZStack(alignment: .topLeading) {
                walls(fit: fit)
                stamps(fit: fit)
                roomLabels(fit: fit)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(.rect)
            .dropDestination(for: String.self) { items, location in
                drop(items, at: location, fit: fit)
            }
        }
    }
}

// 서브 뷰
extension CasePlan2DView {
    /// 벽만 회색 선으로 그린다. 가상 경계선은 그리지 않는다
    private func walls(fit: PlanFit) -> some View {
        Canvas { context, _ in
            for wall in planData.walls where !wall.isVirtual {
                guard let line = planData.line(of: wall) else { continue }
                var path = Path()
                path.move(to: fit.point(line.start))
                path.addLine(to: fit.point(line.end))
                let width = max(wall.thickness * fit.scale, Layout.minimumWallWidth)
                context.stroke(path, with: .color(.gray600), style: StrokeStyle(lineWidth: width, lineCap: .square))
            }
        }
    }

    /// 발화지점·피해자·전기 스탬프 기호
    private func stamps(fit: PlanFit) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(planData.markers) { marker in
                stampIcon(marker.kind == .person ? "figure.fall" : "flame.fill")
                    .position(fit.point(marker.position))
            }
            ForEach(planData.wallFixtures) { fixture in
                if let wall = planData.wall(id: fixture.wallId), let line = planData.line(of: wall) {
                    stampIcon("bolt.fill")
                        .position(fit.point(line.point(along: fixture.positionAlongWall)))
                }
            }
        }
        .opacity(isPlacingPhotos ? Layout.dimmedOpacity : 1)
        .accessibilityHidden(true)
    }

    private func stampIcon(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(AppTypography.title2)
            .foregroundStyle(.brand500)
    }

    /// 사진이 있는 장소는 사진 핀, 없는 장소는 이름 캡슐
    private func roomLabels(fit: PlanFit) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(planData.rooms) { room in
                Group {
                    if let pin = pins[room.id], !isPlacingPhotos {
                        pinView(room: room, pin: pin)
                    } else {
                        nameCapsule(room.name)
                    }
                }
                .position(fit.point(SIMD2(room.labelX, room.labelY)))
            }
        }
    }

    /// 대표 사진 위에 "안방 · 13" 캡슐. 누르면 그 장소의 앨범으로 간다
    private func pinView(room: Room, pin: RoomPhotoPin) -> some View {
        Button {
            onTapRoom(room)
        } label: {
            VStack(spacing: Layout.pinSpacing) {
                Image(uiImage: pin.thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: Layout.pinImageSize, height: Layout.pinImageSize)
                    .clipShape(.rect(cornerRadius: Layout.pinCornerRadius))
                    .overlay {
                        RoundedRectangle(cornerRadius: Layout.pinCornerRadius)
                            .strokeBorder(.white, lineWidth: Layout.pinBorderWidth)
                    }
                    .shadow(radius: Layout.pinShadowRadius)
                HStack(spacing: Layout.countSpacing) {
                    Text(room.name)
                    Text("·")
                    Text(pin.count, format: .number)
                        .foregroundStyle(.white.secondary)
                }
                .font(AppTypography.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, Layout.capsulePadding)
                .padding(.vertical, Layout.capsuleVerticalPadding)
                .background(.gray700, in: .capsule)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Copy.pinLabel(room.name, pin.count))
    }

    /// 사진이 없는 장소의 이름. 사진을 놓는 중에는 회색으로 흐리게 한다
    @ViewBuilder
    private func nameCapsule(_ name: String) -> some View {
        if isPlacingPhotos {
            Text(name)
                .font(AppTypography.headline)
                .foregroundStyle(.white.opacity(Layout.dimmedOpacity))
                .padding(.horizontal, Layout.capsulePadding)
                .padding(.vertical, Layout.capsuleVerticalPadding)
                .background(.gray500, in: .capsule)
        } else {
            RoomLabelView(name: name)
        }
    }
}

// 사진 놓기
extension CasePlan2DView {
    /// 끌어 온 사진 id를 놓은 자리의 장소에 넘긴다. 장소 밖이면 받지 않는다
    private func drop(_ items: [String], at location: CGPoint, fit: PlanFit) -> Bool {
        guard let id = items.first.flatMap(UUID.init(uuidString:)),
              let room = planData.room(containing: fit.planPoint(location)) else { return false }
        onDropPhoto(id, room)
        return true
    }
}

// 도면을 화면에 맞추기
extension CasePlan2DView {
    /// 도면을 비율 그대로 화면 가운데에 놓은 자리. 도면 좌표 ↔ 화면 좌표를 바꾼다
    struct PlanFit {
        /// 꼭짓점을 모두 감싸는 사각형의 왼쪽 위 (도면 좌표, m)
        let minPoint: SIMD2<Double>
        /// 1m가 화면에서 몇 pt인지
        let scale: Double
        /// 도면이 그려지는 화면 사각형의 왼쪽 위
        let origin: CGPoint

        init(planData: PlanData, size: CGSize) {
            let xs = planData.vertices.map(\.x)
            let ys = planData.vertices.map(\.y)
            minPoint = SIMD2(xs.min() ?? 0, ys.min() ?? 0)
            // 꼭짓점이 없거나 한 줄로만 있어도 0으로 나누지 않게 아주 작은 크기를 둔다
            let planWidth = max((xs.max() ?? 0) - minPoint.x, 0.1)
            let planHeight = max((ys.max() ?? 0) - minPoint.y, 0.1)
            scale = min(size.width / planWidth, size.height / planHeight) * Layout.planFill
            origin = CGPoint(
                x: (size.width - planWidth * scale) / 2,
                y: (size.height - planHeight * scale) / 2
            )
        }

        /// 도면 점 (m)을 화면 점으로
        func point(_ p: SIMD2<Double>) -> CGPoint {
            CGPoint(x: origin.x + (p.x - minPoint.x) * scale, y: origin.y + (p.y - minPoint.y) * scale)
        }

        /// 화면 점을 도면 점 (m)으로
        func planPoint(_ point: CGPoint) -> SIMD2<Double> {
            SIMD2((point.x - origin.x) / scale + minPoint.x, (point.y - origin.y) / scale + minPoint.y)
        }
    }
}

// 크기
extension CasePlan2DView {
    fileprivate enum Layout {
        /// 화면에서 도면이 차지하는 몫 (가로·세로 중 꽉 차는 쪽 기준)
        static let planFill = 0.75
        /// 벽이 아주 얇아도 이만큼(pt)은 보이게
        static let minimumWallWidth = 2.0
        static let dimmedOpacity: CGFloat = 0.5
        static let pinImageSize: CGFloat = 76
        static let pinCornerRadius: CGFloat = 14
        static let pinBorderWidth: CGFloat = 2
        static let pinShadowRadius: CGFloat = 4
        static let pinSpacing: CGFloat = 8
        static let countSpacing: CGFloat = 4
        static let capsulePadding: CGFloat = 14
        static let capsuleVerticalPadding: CGFloat = 6
    }
}

// 문구
extension CasePlan2DView {
    private enum Copy {
        static func pinLabel(_ name: String, _ count: Int) -> String {
            "\(name) 사진 \(count)장"
        }
    }
}

#Preview {
    CasePlan2DView(planData: DummyFloorPlan.planData, pins: [:], onTapRoom: { _ in })
}

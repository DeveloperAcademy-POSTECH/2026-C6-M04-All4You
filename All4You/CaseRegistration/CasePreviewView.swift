//
//  CasePreviewView.swift
//  All4You
//
//  Created by SIA on 11/4/26.
//

// 사건 목록에서 사건을 고르면 오른쪽에 뜨는 미리보기. 도면과 앨범,메모 개수를 보여 준다
// 북마크한 사진 중 촬영 위치가 있는 것은 도면 위 그 자리에 번호 핀으로 보여 준다

import SwiftUI

struct CasePreviewView: View {
    let fireCase: FireCase
    /// "사건 열기"를 누르면 도면 탭으로, 앨범·메모 버튼을 누르면 그 탭으로 사건을 연다
    let onOpen: (CaseStartTab) -> Void

    var body: some View {
        floorPlan
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .top) {
                header
            }
            .overlay(alignment: .bottomLeading) {
                HStack(spacing: Layout.buttonSpacing) {
                    countButton(Copy.album, count: "\(fireCase.photos.count)\(Copy.photoUnit)") {
                        onOpen(.album)
                    }
                    countButton(Copy.memo, count: "\(fireCase.memos.count)\(Copy.memoUnit)") {
                        onOpen(.memo)
                    }
                }
                .padding()
            }
    }
}

// 서브 뷰
extension CasePreviewView {
    /// 사건명과 사건 열기 버튼
    private var header: some View {
        HStack {
            Text(fireCase.title)
                // TEMP: Figma는 Large Title(34pt 굵게)인데 AppTypography에 없어 애플 기본 글꼴을 씀
                .font(.largeTitle.bold())
            Spacer()
            Button(Copy.open) { onOpen(.floorPlan) }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                // TEMP: 팀 공용 색이 정해지면 바꿔야 함 (Figma 기준 검정)
                .tint(.black)
        }
        .padding()
    }

    /// 사건에 저장된 도면을 2D 미리보기로 표시
    @ViewBuilder
    private var floorPlan: some View {
        if let planData = fireCase.floorPlan?.loadPlanData(),
           !planData.vertices.isEmpty {

            GeometryReader { geometry in
                // 도면과 북마크 핀이 같은 화면 자리를 쓰도록 screen을 하나 만들어 함께 넘긴다
                let screen = PlanScreen(plan: planData, in: geometry.size, fill: 0.70)
                ZStack(alignment: .topLeading) {
                    Plan2DView(planData: planData, screen: screen)
                    BookmarkPhotoMarkerLayer(
                        markers: BookmarkPhotoMarker.markers(for: latestSessionPhotos, in: planData),
                        screen: screen,
                        showsDirection: false,
                        style: .compact
                    )
                }
                .frame(
                    width: geometry.size.width,
                    height: geometry.size.height
                )
                .allowsHitTesting(false)
            }

        } else {
            Text(Copy.floorPlanPlaceholder)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// 사건을 열면 처음 보이는 차수(가장 최근 차수)의 사진. 차수 없이 들어온 사진은 모든 차수에 보이므로 함께 넣는다.
    /// 사건 화면의 북마크 번호와 같은 번호가 되게 PhotoStore와 같은 기준으로 고른다
    private var latestSessionPhotos: [EvidencePhoto] {
        let latest = fireCase.sessions.map(\.sessionNumber).max()
        return fireCase.photos.filter { photo in
            guard let latest, let number = photo.session?.sessionNumber else { return true }
            return number == latest
        }
    }

    private func countButton(_ title: String, count: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(AppTypography.title2)
                Spacer()
                Text(count)
                    .font(AppTypography.title3)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, Layout.buttonHorizontalPadding)
            // 높이는 Figma 값으로 고정하고, 너비는 Figma 값까지 쓰되 미리보기가 좁으면 두 버튼이 나눠 줄어든다
            .frame(maxWidth: Layout.buttonWidth)
            .frame(height: Layout.buttonHeight)
            .foregroundStyle(Color.primary)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        // .glass 버튼 스타일은 자체 여백이 붙어 크기가 달라지므로, 크기를 고정한 뒤 유리 효과만 입힌다
        .glassEffect(.regular.interactive(), in: .capsule)
    }
}

// 크기
extension CasePreviewView {
    private enum Layout {
        static let buttonSpacing: CGFloat = 8
        static let buttonWidth: CGFloat = 246
        static let buttonHeight: CGFloat = 55
        static let buttonHorizontalPadding: CGFloat = 20
    }
}

// 문구
extension CasePreviewView {
    private enum Copy {
        static let album = "앨범"
        static let memo = "메모"
        static let photoUnit = "장"
        static let memoUnit = "개"
        static let floorPlanPlaceholder = "도면 자리"
        static let open = "사건 열기"
    }
}

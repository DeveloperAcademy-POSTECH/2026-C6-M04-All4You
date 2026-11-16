// 화면 위·아래에 띄우는 컴포넌트(뒤로가기·체크, 가운데 막대, 오른쪽 위 버튼, 스탬프 도구, 필터, 방위표, 치수, 시점 초기화 등)가 함께 쓰는 자리 값.
// 기준은 공용 상단 바(Global/Toolbar.swift)의 뒤로가기·체크 버튼이다.
// 윗줄은 안전 영역에서 topInset만큼 아래에 둔다. 사건 메인의 가운데 탭 막대(시스템)도 같은 값만큼 내려, 모든 화면의 윗줄이 한 줄에 놓인다

import SwiftUI

enum BarLayout {
    /// 화면 왼쪽·오른쪽·아래 가장자리에서 컴포넌트까지
    static let edgeInset: CGFloat = 32
    /// 안전 영역 맨 위에서 윗줄까지. 모든 화면이 같은 값을 쓴다
    static let topInset: CGFloat = 24
    /// 윗줄 버튼(뒤로가기·체크)의 크기. 같은 줄에 놓는 것은 이 높이에 맞춘다
    static let controlSize: CGFloat = 44
    /// 윗줄 버튼의 아이콘 크기
    static let iconSize: CGFloat = 17
    /// 윗줄 안에서 버튼 사이
    static let rowSpacing: CGFloat = 12
    /// 윗줄 아래 여백. 공용 상단 바는 이만큼 띄우고 화면 내용을 시작한다
    static let rowBottomInset: CGFloat = 16
    /// 윗줄 아래에 띄우는 컴포넌트(스탬프 도구·필터·방위표)를 화면 내용 위쪽에서 띄우는 거리
    static let contentTopInset: CGFloat = 16
}

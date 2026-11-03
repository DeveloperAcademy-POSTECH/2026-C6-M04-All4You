//
//  AppTypography.swift
//  All4You
//
//  Created by SIA on 11/3/26.
//

import SwiftUI
/// Usage:
/// ```swift
/// Text("사건 등록")
///     .font(AppTypography.title1Emphasized)
///     .foregroundStyle(.brand500)
/// ```
enum AppTypography {

    // MARK: - Title 1
    // Figma: 28pt / Line Height 34pt

    /// SF Pro Regular
    static let title1: Font = .title.weight(.regular)

    /// SF Pro Bold
    static let title1Emphasized: Font = .title.weight(.bold)


    // MARK: - Title 2
    // Figma: 22pt / Line Height 28pt

    /// SF Pro Regular
    static let title2: Font = .title2.weight(.regular)

    /// SF Pro Bold
    static let title2Emphasized: Font = .title2.weight(.bold)


    // MARK: - Title 3
    // Figma: 20pt / Line Height 25pt

    /// SF Pro Regular
    static let title3: Font = .title3.weight(.regular)

    /// SF Pro Semibold
    static let title3Emphasized: Font = .title3.weight(.semibold)


    // MARK: - Headline
    // Figma: 17pt / Line Height 22pt

    /// SF Pro Regular
    static let headline: Font = .body.weight(.regular)

    /// SF Pro Semibold
    static let headlineEmphasized: Font = .headline


    // MARK: - Subheadline
    // Figma: 15pt / Line Height 20pt

    /// SF Pro Regular
    static let subheadline: Font = .subheadline.weight(.regular)

    /// SF Pro Semibold
    static let subheadlineEmphasized: Font = .subheadline.weight(.semibold)


    // MARK: - Supporting Label
    // Figma: 12pt / Line Height 16pt

    /// SF Pro Regular
    static let label: Font = .caption
}

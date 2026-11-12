//
//  FloorPlanMemoInteractiveContent.swift
//  All4You
//
//  Created by 채유성 on 11/09/26.
//

// 메모 상세 본문의 일반 텍스트 탭과 사진 태그 탭을 구분하는 읽기 전용 텍스트 뷰
import SwiftUI
import UIKit

struct FloorPlanMemoInteractiveContent: UIViewRepresentable {
    let memo: FloorPlanMemo
    let bookmarkedPhotos: [LoadedPhoto]
    let onPhotoTap: (LoadedPhoto) -> Void
    let onBodyTap: () -> Void
    
    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.backgroundColor = .clear
        view.isEditable = false
        view.isSelectable = false
        view.isScrollEnabled = false
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.addGestureRecognizer(UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        ))
        return view
    }
    
    func updateUIView(_ view: UITextView, context: Context) {
        let matches = FloorPlanMemoPhotoTags.matches(in: memo, bookmarkedPhotos: bookmarkedPhotos)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 7
        let text = NSMutableAttributedString(string: memo.content, attributes: [
            .font: UIFont.preferredFont(forTextStyle: .body),
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraph
        ])
        for match in matches where match.photo != nil {
            text.addAttributes([
                .foregroundColor: UIColor(Color.brand500),
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ], range: match.range)
        }
        view.attributedText = text
        view.accessibilityLabel = memo.content
        context.coordinator.view = view
        context.coordinator.links = matches.compactMap { match in
            match.photo.map { Link(range: match.range, photo: $0) }
        }
        context.coordinator.onPhotoTap = onPhotoTap
        context.coordinator.onBodyTap = onBodyTap
    }
    
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? uiView.bounds.width
        guard width > 0 else { return nil }
        let measured = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: max(60, ceil(measured.height)))
    }
    
    func makeCoordinator() -> Coordinator { Coordinator() }
    
    struct Link {
        let range: NSRange
        let photo: LoadedPhoto
    }
    
    final class Coordinator: NSObject {
        weak var view: UITextView?
        var links: [Link] = []
        var onPhotoTap: ((LoadedPhoto) -> Void)?
        var onBodyTap: (() -> Void)?
        
        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let view, recognizer.state == .ended else { return }
            guard view.layoutManager.numberOfGlyphs > 0 else {
                onBodyTap?()
                return
            }
            let location = recognizer.location(in: view)
            let point = CGPoint(
                x: location.x - view.textContainerInset.left,
                y: location.y - view.textContainerInset.top
            )
            let glyphIndex = view.layoutManager.glyphIndex(for: point, in: view.textContainer)
            let glyphRect = view.layoutManager.boundingRect(
                forGlyphRange: NSRange(location: glyphIndex, length: 1),
                in: view.textContainer
            )
            if glyphRect.contains(point) {
                let characterIndex = view.layoutManager.characterIndexForGlyph(at: glyphIndex)
                if let link = links.first(where: { NSLocationInRange(characterIndex, $0.range) }) {
                    onPhotoTap?(link.photo)
                    return
                }
            }
            onBodyTap?()
        }
    }
}

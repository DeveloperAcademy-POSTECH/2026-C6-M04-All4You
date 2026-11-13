//
//  FloorPlanMemoInputField.swift
//  All4You
//
//  Created by 채유성 on 11/12/26.
//

//  메모 입력시 키보드 Enter 키를 줄바꿈 대신 태그 확정 또는 저장 동작으로 전달하는 입력 컴포넌트
import SwiftUI
import UIKit

struct FloorPlanMemoInputField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    let taggedTokens: Set<String>
    let onSubmit: (String) -> Void
    var textColor: UIColor = .white
    
    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.backgroundColor = .clear
        view.textColor = textColor
        view.tintColor = UIColor(Color.brand500)
        view.font = .preferredFont(forTextStyle: .headline)
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.returnKeyType = .done
        view.isScrollEnabled = true
        view.text = text
        view.selectedRange = NSRange(location: (text as NSString).length, length: 0)
        return view
    }
    
    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.parent = self
        // SwiftUI 뷰 갱신 중 UIKit 델리게이트가 바인딩을 다시 변경하지 않도록 구분
        context.coordinator.isUpdatingUIView = true
        defer { context.coordinator.isUpdatingUIView = false }
        if view.text != text {
            view.text = text
            view.selectedRange = NSRange(location: (text as NSString).length, length: 0)
        }
        if context.coordinator.styledText != text || context.coordinator.styledTokens != taggedTokens {
            let fullRange = NSRange(location: 0, length: (text as NSString).length)
            let baseAttributes: [NSAttributedString.Key: Any] = [
                .font: view.font ?? UIFont.preferredFont(forTextStyle: .headline),
                .foregroundColor: textColor
            ]
            view.textStorage.beginEditing()
            view.textStorage.setAttributes(baseAttributes, range: fullRange)
            for token in taggedTokens {
                let pattern = NSRegularExpression.escapedPattern(for: token) + "(?![0-9])"
                let matches = (try? NSRegularExpression(pattern: pattern))?
                    .matches(in: text, range: fullRange) ?? []
                if let match = matches.first {
                    view.textStorage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: match.range)
                }
            }
            view.textStorage.endEditing()
            view.typingAttributes = baseAttributes
            context.coordinator.styledText = text
            context.coordinator.styledTokens = taggedTokens
        }
        if isFocused && !view.isFirstResponder {
            DispatchQueue.main.async { [weak view, weak coordinator = context.coordinator] in
                guard let view, view.window != nil, coordinator?.parent.isFocused == true else { return }
                view.becomeFirstResponder()
                view.selectedRange = NSRange(location: (view.text as NSString).length, length: 0)
            }
        } else if !isFocused && view.isFirstResponder {
            DispatchQueue.main.async { [weak view, weak coordinator = context.coordinator] in
                guard let view, view.isFirstResponder, coordinator?.parent.isFocused == false else { return }
                view.resignFirstResponder()
            }
        }
    }
    
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: FloorPlanMemoInputField
        var styledText = ""
        var styledTokens: Set<String> = []
        var isUpdatingUIView = false
        
        init(parent: FloorPlanMemoInputField) { self.parent = parent }
        
        func textViewDidChange(_ textView: UITextView) {
            guard !isUpdatingUIView, parent.text != textView.text else { return }
            parent.text = textView.text
        }
        
        func textViewDidBeginEditing(_ textView: UITextView) {
            guard !isUpdatingUIView else { return }
            DispatchQueue.main.async { [weak self, weak textView] in
                guard let self, let textView, textView.isFirstResponder, !self.parent.isFocused else { return }
                self.parent.isFocused = true
            }
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            guard !isUpdatingUIView else { return }
            DispatchQueue.main.async { [weak self, weak textView] in
                guard let self, let textView, !textView.isFirstResponder, self.parent.isFocused else { return }
                self.parent.isFocused = false
            }
        }
        
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            guard text == "\n" else { return true }
            // SwiftUI 상태 갱신보다 Return 이벤트가 먼저 도착해도 마지막 입력 문자를 잃지 않도록 원문 전달
            let currentText = textView.text ?? ""
            DispatchQueue.main.async { self.parent.onSubmit(currentText) }
            return false
        }
    }
}

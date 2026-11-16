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
    var focusRequestID = 0
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
        let hasNewFocusRequest = context.coordinator.handledFocusRequestID != focusRequestID
        if view.markedTextRange == nil {
            context.coordinator.isUpdatingUIView = true
            defer { context.coordinator.isUpdatingUIView = false }
            if view.text != text && (!view.isFirstResponder || hasNewFocusRequest) {
                view.text = text
                view.selectedRange = NSRange(location: (text as NSString).length, length: 0)
            }
            context.coordinator.updateTagUnderlines(in: view, tokens: taggedTokens)
        }
        if hasNewFocusRequest && view.markedTextRange == nil {
            context.coordinator.handledFocusRequestID = focusRequestID
        }
        if isFocused && (!view.isFirstResponder || hasNewFocusRequest) {
            DispatchQueue.main.async { [weak view, weak coordinator = context.coordinator] in
                guard let view, view.window != nil, coordinator?.parent.isFocused == true else { return }
                if !view.isFirstResponder { view.becomeFirstResponder() }
                if view.markedTextRange == nil {
                    view.selectedRange = NSRange(location: (view.text as NSString).length, length: 0)
                    coordinator?.clearTypingUnderline(in: view)
                }
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
        var styledTokens: Set<String> = []
        var handledFocusRequestID = 0
        var isUpdatingUIView = false
        
        init(parent: FloorPlanMemoInputField) { self.parent = parent }
        
        func updateTagUnderlines(in textView: UITextView, tokens: Set<String>) {
            guard textView.markedTextRange == nil else { return }
            let currentText = textView.text ?? ""
            let fullRange = NSRange(location: 0, length: (currentText as NSString).length)
            let tagRanges = tokens.flatMap { token -> [NSRange] in
                let pattern = NSRegularExpression.escapedPattern(for: token) + "(?![0-9a-z])"
                return (try? NSRegularExpression(pattern: pattern))?
                    .matches(in: currentText, range: fullRange).map(\.range) ?? []
            }
            
            if styledTokens != tokens {
                textView.textStorage.beginEditing()
                textView.textStorage.removeAttribute(.underlineStyle, range: fullRange)
                for range in tagRanges {
                    textView.textStorage.addAttribute(
                        .underlineStyle,
                        value: NSUnderlineStyle.single.rawValue,
                        range: range
                    )
                }
                textView.textStorage.endEditing()
                styledTokens = tokens
                clearTypingUnderline(in: textView)
                return
            }
            
            var leakedRanges: [NSRange] = []
            textView.textStorage.enumerateAttribute(.underlineStyle, in: fullRange, options: []) { value, range, _ in
                guard ((value as? NSNumber)?.intValue ?? 0) != 0 else { return }
                var leakStart: Int?
                for index in range.location..<NSMaxRange(range) {
                    if !tagRanges.contains(where: { NSLocationInRange(index, $0) }) {
                        if leakStart == nil { leakStart = index }
                    } else if let start = leakStart {
                        leakedRanges.append(NSRange(location: start, length: index - start))
                        leakStart = nil
                    }
                }
                if let start = leakStart {
                    leakedRanges.append(NSRange(location: start, length: NSMaxRange(range) - start))
                }
            }
            guard !leakedRanges.isEmpty else { return }
            textView.textStorage.beginEditing()
            for range in leakedRanges {
                textView.textStorage.removeAttribute(.underlineStyle, range: range)
            }
            textView.textStorage.endEditing()
            clearTypingUnderline(in: textView)
        }
        
        func clearTypingUnderline(in textView: UITextView) {
            guard textView.markedTextRange == nil else { return }
            var attributes = textView.typingAttributes
            attributes[.underlineStyle] = 0
            attributes[.font] = textView.font ?? UIFont.preferredFont(forTextStyle: .headline)
            attributes[.foregroundColor] = parent.textColor
            textView.typingAttributes = attributes
        }
        
        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !isUpdatingUIView else { return }
            clearTypingUnderline(in: textView)
        }
        
        func textViewDidChange(_ textView: UITextView) {
            // 조합 중에도 첫 글자를 전달해 태그를 즉시 확정. updateUIView는 조합 중 텍스트를 교체하지 않음
            guard !isUpdatingUIView,
                  parent.text != textView.text else { return }
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
            if parent.text != textView.text {
                parent.text = textView.text
            }
            let focusRequestAtEnd = parent.focusRequestID
            // 태그 버튼으로 포커스가 잠깐 이동한 경우 입력 종료로 처리하지 않음
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self, weak textView] in
                guard let self, let textView, !textView.isFirstResponder,
                      self.parent.focusRequestID == focusRequestAtEnd,
                      self.parent.isFocused else { return }
                self.parent.isFocused = false
            }
        }
        
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            guard text == "\n" else {
                clearTypingUnderline(in: textView)
                return true
            }
            // SwiftUI 상태 갱신보다 Return 이벤트가 먼저 도착해도 마지막 입력 문자를 잃지 않도록 원문 전달
            let currentText = textView.text ?? ""
            DispatchQueue.main.async { self.parent.onSubmit(currentText) }
            return false
        }
    }
}

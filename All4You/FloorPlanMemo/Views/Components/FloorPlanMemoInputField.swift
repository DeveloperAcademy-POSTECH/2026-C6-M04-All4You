//
//  FloorPlanMemoInputField.swift
//  All4You
//
//  Created by 채유성 on 11/12/26.
//

//  메모 입력시 키보드 Enter 키를 줄바꿈 대신 저장 동작으로 수행하도록 하는 로직
import SwiftUI
import UIKit

struct FloorPlanMemoInputField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    let onSubmit: () -> Void
    
    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.backgroundColor = .clear
        view.textColor = .white
        view.font = .preferredFont(forTextStyle: .headline)
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.returnKeyType = .done
        view.isScrollEnabled = true
        view.text = text
        return view
    }
    
    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.parent = self
        if view.text != text { view.text = text }
        if isFocused && !view.isFirstResponder {
            DispatchQueue.main.async { [weak view, weak coordinator = context.coordinator] in
                guard let view, view.window != nil, coordinator?.parent.isFocused == true else { return }
                view.becomeFirstResponder()
            }
        } else if !isFocused && view.isFirstResponder {
            view.resignFirstResponder()
        }
    }
    
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: FloorPlanMemoInputField
        
        init(parent: FloorPlanMemoInputField) { self.parent = parent }
        
        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }
        
        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.isFocused = true
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            parent.isFocused = false
        }
        
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            guard text == "\n" else { return true }
            DispatchQueue.main.async { self.parent.onSubmit() }
            return false
        }
    }
}

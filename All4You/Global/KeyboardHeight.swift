// 화면에 올라온 키보드의 높이를 알려 주는 도우미.
// 이름 입력칸이 키보드에 가리면 화면 전체를 올리는데, 올리고 내리는 일을 "이름 고치기를 시작·끝냄"이 아니라 "키보드가 올라오고 내려감"에 맞춘다.
// 그러면 엔터·키보드 내리기 버튼·바깥 누르기 어느 쪽으로 끝내도 키보드가 내려갈 때 도면이 함께 같은 방식으로 내려오고,
// 도면이 키보드와 같은 곡선·속도로 움직여 따로 노는 느낌이 없다.
// 화면 크기를 재지 않고 키보드가 알려 주는 값만 쓰므로, 화면을 올려도 값이 바뀌지 않는다

import SwiftUI
import UIKit

extension View {
    /// 키보드가 올라오거나 내려가기 시작할 때 알린다. height는 올라온 키보드의 높이(pt, 내려가면 0), duration은 키보드가 알려 주는 시간(초)
    func onKeyboardChange(_ action: @escaping (_ height: CGFloat, _ duration: Double) -> Void) -> some View {
        onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            guard let end = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            // 키보드를 내리면 끝 자리가 화면 아래로 나간다
            let isShown = end.minY < ((note.object as? UIScreen)?.bounds.height ?? KeyboardHeight.screenHeight)
            let duration = note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.35
            action(isShown ? end.height : 0, duration)
        }
    }
}

enum KeyboardHeight {
    /// 도면·3D 화면을 올리고 내릴 때 쓰는 곡선. 2D·3D가 같은 값을 쓴다
    static let animation = Animation.easeInOut(duration: 0.5)

    /// 지금 앱이 떠 있는 기기 화면의 높이 (pt). UIScreen.main은 iOS 26에서 쓰지 않게 되어, 창이 속한 장면에서 얻는다
    static var screenHeight: CGFloat {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        return scene?.screen.bounds.height ?? 0
    }

    /// 입력칸 아래에 키보드 윗변과 두는 여유 (pt)
    private static let clearance: CGFloat = 40

    /// 이름 입력칸이 키보드에 가리지 않게 화면 전체를 올릴 거리 (pt, 위로 올리면 음수). 2D·3D 수정 화면이 같은 계산을 쓴다.
    /// labelY는 올리지 않은 화면 안에서 입력칸의 높이, originY는 그 화면 윗변의 기기 화면 기준 높이다.
    /// 입력칸이 키보드에 가릴 때만, 가리지 않을 만큼만 올리고, 키보드 높이보다 더 올리지 않는다
    static func lift(labelY: CGFloat?, originY: CGFloat, keyboardHeight: CGFloat) -> CGFloat {
        guard let labelY, keyboardHeight > 0 else { return 0 }
        let keyboardTop = screenHeight - keyboardHeight
        let needed = originY + labelY - (keyboardTop - clearance)
        return -min(max(needed, 0), keyboardHeight)
    }
}

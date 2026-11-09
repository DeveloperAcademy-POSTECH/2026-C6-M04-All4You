// 도면 되돌리기·다시 하기 기록. 2D·3D 수정 화면이 하나의 기록을 함께 쓴다
// PlanData가 값 타입이라 바뀌기 전 도면을 그대로 담아 두면 그 순간으로 돌아갈 수 있다

/// 도면이 바뀔 때마다 바뀌기 전 도면을 한 칸씩 쌓는다. 끌기는 손을 뗄 때 도면이 한 번만 바뀌므로 한 칸이 된다
struct PlanHistory {
    private var undoStack: [PlanData] = []
    private var redoStack: [PlanData] = []
    /// 되돌리기·다시 하기로 넣은 도면. 이 값으로 바뀐 것은 새 편집이 아니므로 기록하지 않는다
    private var restoring: PlanData?

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    /// 도면이 old에서 new로 바뀌었음을 기록한다. 새 편집이 들어오면 다시 하기 기록은 지운다
    mutating func record(from old: PlanData, to new: PlanData) {
        if let restoring, restoring == new {
            self.restoring = nil
            return
        }
        undoStack.append(old)
        if undoStack.count > Self.limit { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    /// 한 칸 전 도면. 지금 도면은 다시 하기 쪽에 쌓는다
    mutating func undo(from current: PlanData) -> PlanData? {
        guard let previous = undoStack.popLast() else { return nil }
        redoStack.append(current)
        restoring = previous
        return previous
    }

    /// 되돌렸던 한 칸 뒤 도면. 지금 도면은 되돌리기 쪽에 쌓는다
    mutating func redo(from current: PlanData) -> PlanData? {
        guard let next = redoStack.popLast() else { return nil }
        undoStack.append(current)
        restoring = next
        return next
    }

    // TEMP: 기록 칸 수는 실기기에서 메모리를 보고 정함
    private static let limit = 50
}

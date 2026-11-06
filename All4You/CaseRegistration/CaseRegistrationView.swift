//
//  CaseRegistrationView.swift
//  All4You
//
//  Created by SIA on 11/2/26.
//

// 새로운 사건 등록 시트. 출동 날짜·시간과 주소를 받는다

import SwiftUI

struct CaseRegistrationView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var date: Date?
    @State private var time: Date?
    @State private var address = ""
    @State private var isDatePickerOpen = false
    @State private var isTimePickerOpen = false
    @State private var addressSearch = AddressSearch()
    @FocusState private var isAddressFocused: Bool
    
    let onRegister: (FireCase) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    dateRow
                    timeRow
                    addressRow
                    if isAddressFocused {
                        suggestionRows
                    }
                }
            }
            .navigationTitle(Copy.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .onChange(of: address) { _, newValue in
                addressSearch.update(query: newValue)
            }
            .task {
                await fillCurrentAddress()
            }
        }
    }
}

// 입력 줄
extension CaseRegistrationView {
    private var dateRow: some View {
        pickerRow(
            systemImage: "calendar",
            text: date.map { Self.dateFormatter.string(from: $0) },
            placeholder: Copy.datePlaceholder,
            isOpen: $isDatePickerOpen
        ) {
            DatePicker(Copy.datePlaceholder, selection: dateSelection, in: ...Date.now, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .frame(width: Layout.calendarWidth)
                .padding()
                .onAppear { date = date ?? .now }
        }
    }
    
    private var timeRow: some View {
        pickerRow(
            systemImage: "clock",
            text: time.map { Self.timeFormatter.string(from: $0) },
            placeholder: Copy.timePlaceholder,
            isOpen: $isTimePickerOpen
        ) {
            DatePicker(Copy.timePlaceholder, selection: timeSelection, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
            // 휠을 24시간제로 보여 주기 위함
                .environment(\.locale, Locale(identifier: "en_GB"))
                .padding()
                .onAppear { time = time ?? .now }
        }
    }
    
    private var addressRow: some View {
        HStack(spacing: Layout.iconSpacing) {
            Image(systemName: "location")
                .foregroundStyle(address.isEmpty ? Color(uiColor: .placeholderText) : Color.primary)
            TextField(Copy.addressPlaceholder, text: $address)
                .focused($isAddressFocused)
                .submitLabel(.done)
            if !address.isEmpty {
                Button(Copy.clear, systemImage: "xmark.circle.fill") {
                    address = ""
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
            }
        }
        .fontWeight(.semibold)
    }
    
    /// 주소 줄 아래에 붙는 주소 추천 목록
    private var suggestionRows: some View {
        ForEach(addressSearch.suggestions) { suggestion in
            Button {
                address = suggestion.address
                isAddressFocused = false
                addressSearch.clear()
            } label: {
                Text(suggestion.highlighted)
                    .font(.callout)
                    .foregroundStyle(Color.primary)
                    .padding(.leading, Layout.suggestionIndent)
            }
        }
    }
    
    // 누르면 바로 아래에 선택 창이 뜨는 한 줄. 고르기 전에는 흐린 안내 문구를 보여 준다
    private func pickerRow<Content: View>(
        systemImage: String,
        text: String?,
        placeholder: String,
        isOpen: Binding<Bool>,
        @ViewBuilder picker: @escaping () -> Content
    ) -> some View {
        Button {
            isAddressFocused = false
            isOpen.wrappedValue = true
        } label: {
            HStack(spacing: Layout.iconSpacing) {
                Image(systemName: systemImage)
                    .foregroundStyle(text == nil ? .tertiary : .primary)
                // 주소 줄 아이콘과 같은 옅은 색
                    .foregroundStyle(.tertiary)
                Text(text ?? placeholder)
                // 고르기 전 안내 문구는 주소 입력칸의 안내 문구와 같은 색으로 맞춘다
                    .foregroundStyle(text == nil ? Color(uiColor: .placeholderText) : Color.primary)
                Spacer()
            }
            .fontWeight(.semibold)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .popover(isPresented: isOpen, attachmentAnchor: .point(.bottomLeading), arrowEdge: .top) {
            picker()
                .presentationCompactAdaptation(.popover)
        }
    }
}

// 상단 바
extension CaseRegistrationView {
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(role: .close) {
                dismiss()
            }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button(role: .confirm, action: register)
                .disabled(!isValid)
                .tint(.brand500)
        }
    }
}

// 입력값
extension CaseRegistrationView {
    private var dateSelection: Binding<Date> {
        Binding(get: { date ?? .now }, set: { date = $0 })
    }
    
    private var timeSelection: Binding<Date> {
        Binding(get: { time ?? .now }, set: { time = $0 })
    }
    
    private var trimmedAddress: String {
        address.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// 고른 날짜에 고른 시각을 합친 출동 일시
    private var occurredAt: Date? {
        guard let date, let time else { return nil }
        let calendar = Calendar.current
        let clock = calendar.dateComponents([.hour, .minute], from: time)
        return calendar.date(
            bySettingHour: clock.hour ?? 0,
            minute: clock.minute ?? 0,
            second: 0,
            of: date
        )
    }
    
    /// 세 칸이 모두 채워졌고 출동 일시가 미래가 아닐 때만 등록할 수 있다
    private var isValid: Bool {
        guard let occurredAt else { return false }
        return !trimmedAddress.isEmpty && occurredAt <= .now
    }
    
    private func register() {
        guard isValid, let occurredAt else { return }
        onRegister(FireCase(address: trimmedAddress, occurredAt: occurredAt))
    }
    
    /// 시트가 뜨면 현재 위치의 주소를 미리 채운다. 그 사이 직접 입력했다면 덮어쓰지 않는다
    private func fillCurrentAddress() async {
        guard address.isEmpty, let current = await CurrentAddress.fetch() else { return }
        if address.isEmpty {
            address = current
        }
    }
}

// 날짜 형식
extension CaseRegistrationView {
    /// 예) 2026 / 10 / 28
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy / MM / dd"
        return formatter
    }()
    
    /// 예) 13 : 30
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH : mm"
        return formatter
    }()
}

// 크기
extension CaseRegistrationView {
    private enum Layout {
        static let iconSpacing: CGFloat = 8
        static let suggestionIndent: CGFloat = 24
        static let calendarWidth: CGFloat = 320
    }
}

// 문구
extension CaseRegistrationView {
    private enum Copy {
        static let title = "새로운 사건"
        static let datePlaceholder = "년 / 월 / 일"
        static let timePlaceholder = "출동시간"
        static let addressPlaceholder = "주소"
        static let clear = "지우기"
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            CaseRegistrationView { _ in }
        }
}

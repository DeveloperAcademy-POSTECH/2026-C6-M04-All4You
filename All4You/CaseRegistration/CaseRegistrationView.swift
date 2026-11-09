//
//  CaseRegistrationView.swift
//  All4You
//
//  Created by SIA on 11/2/26.
//

// 새로운 사건 등록 시트. 사건명 / 출동 정보(날짜·시간) / 현장 정보(주소·상세 주소) 세 묶음으로 받는다.
// 사건명은 주소·상세 주소로 자동으로 채우고("청암로 77 1층 207호 화재"), 직접 고치면 그 뒤로는 덮어쓰지 않는다

import SwiftData
import SwiftUI

struct CaseRegistrationView: View {
    @Environment(\.dismiss) private var dismiss
    /// 기본 사건명 번호를 정하려고 이미 있는 사건 이름을 본다
    @Query private var existingCases: [FireCase]
    
    @State private var date: Date?
    @State private var time: Date?
    @State private var address = ""
    @State private var detailAddress = ""
    /// 주소·상세 주소로 자동으로 채운다. 사용자가 고칠 수 있다
    @State private var caseName = ""
    /// 사용자가 사건명을 직접 고쳤는지. 고쳤으면 주소가 바뀌어도 사건명을 덮어쓰지 않는다 (다 지우면 다시 자동)
    @State private var isCaseNameEdited = false
    @State private var isDatePickerOpen = false
    @State private var isTimePickerOpen = false
    @State private var addressSearch = AddressSearch()
    @FocusState private var isAddressFocused: Bool
    
    let onRegister: (FireCase) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section(Copy.caseNameSection) {
                    caseNameRow
                }
                Section(Copy.dispatchSection) {
                    dateRow
                    timeRow
                }
                Section(Copy.siteSection) {
                    addressRow
                    if isAddressFocused {
                        suggestionRows
                    }
                    detailAddressRow
                }
            }
            .navigationTitle(Copy.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .onChange(of: address) { _, newValue in
                addressSearch.update(query: newValue)
                updateAutoCaseName()
            }
            .onChange(of: detailAddress) { _, _ in
                updateAutoCaseName()
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
    
    /// 층·호수 등 상세 주소. 넣지 않아도 된다. Figma처럼 아이콘 없이 주소 글자 줄에 맞춰 들여 쓴다
    private var detailAddressRow: some View {
        textRow(systemImage: "location", isIconHidden: true, placeholder: Copy.detailAddressPlaceholder, text: $detailAddress)
    }
    
    /// 사건명. 주소·상세 주소로 자동으로 채우고, 직접 고치면 그 뒤로는 자동으로 바꾸지 않는다
    private var caseNameRow: some View {
        textRow(systemImage: "doc.text", placeholder: Copy.caseNamePlaceholder, text: caseNameBinding)
    }
    
    /// 아이콘·입력칸·지우기 버튼으로 된 한 줄 (주소 줄과 같은 모양).
    /// isIconHidden이면 아이콘 자리만 비워 두어 위 줄 글자와 시작점을 맞춘다
    private func textRow(systemImage: String, isIconHidden: Bool = false, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: Layout.iconSpacing) {
            Image(systemName: systemImage)
                .foregroundStyle(text.wrappedValue.isEmpty ? Color(uiColor: .placeholderText) : Color.primary)
                .opacity(isIconHidden ? 0 : 1)
                .accessibilityHidden(isIconHidden)
            TextField(placeholder, text: text)
                .submitLabel(.done)
            if !text.wrappedValue.isEmpty {
                Button(Copy.clear, systemImage: "xmark.circle.fill") {
                    text.wrappedValue = ""
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
            Button(role: .confirm) {
                register()
            }
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
    
    /// 줄바꿈·쉼표·끝의 우편번호를 정리한 주소
    private var trimmedAddress: String {
        FireCase.cleanedAddress(address)
    }
    
    private var trimmedDetailAddress: String {
        detailAddress.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// 사건명 칸. 사용자가 고치면 '직접 고침'으로 표시해 자동 생성이 덮어쓰지 않게 한다
    private var caseNameBinding: Binding<String> {
        Binding(
            get: { caseName },
            set: { newValue in
                caseName = newValue
                isCaseNameEdited = !newValue.isEmpty && newValue != autoCaseName
            }
        )
    }
    
    /// 주소·상세 주소로 만든 사건명 ("청암로 77 1층 207호 화재")
    private var autoCaseName: String {
        FireCase.autoCaseName(address: trimmedAddress, detailAddress: trimmedDetailAddress)
    }
    
    private func updateAutoCaseName() {
        guard !isCaseNameEdited else { return }
        caseName = autoCaseName
    }
    
    /// 사건명도 주소도 없을 때만 쓰는 기본 사건명 "새 사건_N". N은 이미 있는 "새 사건_숫자" 중 가장 큰 번호 다음
    private var defaultCaseName: String {
        let numbers = existingCases.compactMap { fireCase -> Int? in
            guard fireCase.caseName.hasPrefix(Copy.defaultCaseNamePrefix) else { return nil }
            return Int(fireCase.caseName.dropFirst(Copy.defaultCaseNamePrefix.count))
        }
        return Copy.defaultCaseNamePrefix + String((numbers.max() ?? 0) + 1)
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
    
    /// 사건명을 비워 두면 주소로 만든 사건명, 그것도 없으면 기본 사건명("새 사건_N")으로 저장한다. 주소·상세 주소·사건명은 따로 저장한다
    private func register() {
        guard isValid, let occurredAt else { return }
        let trimmedCaseName = caseName.trimmingCharacters(in: .whitespacesAndNewlines)
        onRegister(
            FireCase(
                address: trimmedAddress,
                detailAddress: trimmedDetailAddress,
                caseName: [trimmedCaseName, autoCaseName, defaultCaseName].first { !$0.isEmpty } ?? defaultCaseName,
                occurredAt: occurredAt
            )
        )
    }
    
    /// 시트가 뜨면 현재 위치의 주소를 미리 채운다. 그 사이 직접 입력했다면 덮어쓰지 않는다
    private func fillCurrentAddress() async {
        guard address.isEmpty, let current = await CurrentAddress.fetch() else { return }
        if address.isEmpty {
            address = FireCase.cleanedAddress(current)
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
        static let detailAddressPlaceholder = "상세 주소 (층 · 호수)"
        static let caseNamePlaceholder = "주소 입력 후 자동 생성"
        static let caseNameSection = "사건명"
        static let dispatchSection = "출동 정보"
        static let siteSection = "현장 정보"
        /// 기본 사건명 앞부분. 뒤에 번호를 붙인다
        static let defaultCaseNamePrefix = "새 사건_"
        static let clear = "지우기"
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            CaseRegistrationView { _ in }
        }
}

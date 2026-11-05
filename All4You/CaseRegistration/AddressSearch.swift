//
//  AddressSearch.swift
//  All4You
//
//  Created by SIA on 11/4/26.
//

// 주소 입력을 돕는 두 가지: 입력 중 주소 추천, 현재 위치의 주소

import CoreLocation
import MapKit
import Observation
import SwiftUI

/// 주소 추천 한 줄
struct AddressSuggestion: Identifiable {
    let id = UUID()
    /// 고르면 입력칸에 들어갈 주소
    let address: String
    /// 입력한 글자와 겹치는 부분이 굵게 표시된 주소
    let highlighted: AttributedString
}

/// 입력한 글자로 주소 후보를 찾는다
@Observable
final class AddressSearch: NSObject, MKLocalSearchCompleterDelegate {
    private(set) var suggestions: [AddressSuggestion] = []

    @ObservationIgnored private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.resultTypes = .address
        completer.delegate = self
    }

    func update(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            clear()
        } else {
            completer.queryFragment = trimmed
        }
    }

    func clear() {
        completer.cancel()
        suggestions = []
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        MainActor.assumeIsolated {
            suggestions = completer.results.prefix(Self.maxCount).map { Self.suggestion(from: $0) }
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        MainActor.assumeIsolated {
            suggestions = []
        }
    }
}

extension AddressSearch {
    private static let maxCount = 5

    // TODO: 실제 기기에서 국내 주소의 title/subtitle 형태 확인 — 지금은 title을 전체 주소로 본다
    private static func suggestion(from completion: MKLocalSearchCompletion) -> AddressSuggestion {
        let title = completion.title
        var highlighted = AttributedString(title)
        for value in completion.titleHighlightRanges {
            guard let stringRange = Range(value.rangeValue, in: title),
                  let range = Range(stringRange, in: highlighted) else { continue }
            highlighted[range].font = Font.callout.bold()
        }
        if let prefix = highlighted.range(of: countryPrefix), prefix.lowerBound == highlighted.startIndex {
            highlighted.removeSubrange(prefix)
        }
        return AddressSuggestion(address: removingCountry(title), highlighted: highlighted)
    }

    /// "대한민국 경상북도 ..."처럼 나라 이름이 붙어 오면 뗀다
    static func removingCountry(_ address: String) -> String {
        address.hasPrefix(countryPrefix) ? String(address.dropFirst(countryPrefix.count)) : address
    }

    private static let countryPrefix = "대한민국 "
}

/// 현재 위치의 도로명 주소를 한 번 가져온다
enum CurrentAddress {
    /// 위치 권한을 허용하지 않았거나 주소를 찾지 못하면 nil
    static func fetch() async -> String? {
        // 권한 팝업을 확실히 띄우기 위해 직접 요청한다. 답을 받을 때까지 manager를 살려 둔다
        let manager = CLLocationManager()
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        let session = CLServiceSession(authorization: .whenInUse)
        defer {
            session.invalidate()
            _ = manager
        }

        do {
            for try await update in CLLocationUpdate.liveUpdates() {
                // TEMP: 위치 확인용 로그 — 확인 후 삭제
                print("위치 업데이트:", update.location as Any,
                      "거부:", update.authorizationDenied,
                      "요청 중:", update.authorizationRequestInProgress)
                if let location = update.location {
                    return await address(of: location)
                }
                if update.authorizationDenied || update.authorizationDeniedGlobally || update.authorizationRestricted {
                    return nil
                }
            }
        } catch {
            print("위치 오류:", error)
            return nil
        }
        return nil
    }
    
    private static func address(of location: CLLocation) async -> String? {
        guard let request = MKReverseGeocodingRequest(location: location),
              let mapItem = try? await request.mapItems.first,
              let address = mapItem.address?.fullAddress else { return nil }
        return AddressSearch.removingCountry(address)
    }
}

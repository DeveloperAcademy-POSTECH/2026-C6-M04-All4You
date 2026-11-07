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
            suggestions = completer.results.prefix(Self.maxCount).map {
                Self.suggestion(from: $0)
            }
        }
    }

    nonisolated func completer(
        _ completer: MKLocalSearchCompleter,
        didFailWithError error: Error
    ) {
        MainActor.assumeIsolated {
            suggestions = []
        }
    }
}

// 주소 추천 및 국가명 처리

extension AddressSearch {
    private static let maxCount = 5

    // TODO: 실제 기기에서 국내 주소의 title/subtitle 형태 확인
    // 지금은 title을 전체 주소로 본다
    private static func suggestion(
        from completion: MKLocalSearchCompletion
    ) -> AddressSuggestion {
        let title = completion.title
        var highlighted = AttributedString(title)

        for value in completion.titleHighlightRanges {
            guard let stringRange = Range(value.rangeValue, in: title),
                  let range = Range(stringRange, in: highlighted)
            else {
                continue
            }

            highlighted[range].font = Font.callout.bold()
        }

        for prefix in countryPrefixes {
            if let range = highlighted.range(of: prefix),
               range.lowerBound == highlighted.startIndex {
                highlighted.removeSubrange(range)
                break
            }
        }

        return AddressSuggestion(
            address: removingCountry(title),
            highlighted: highlighted
        )
    }

    /// 주소 앞에 국가명이 포함된 경우 제거한다
    static func removingCountry(_ address: String) -> String {
        for prefix in countryPrefixes {
            if address.hasPrefix(prefix) {
                return String(address.dropFirst(prefix.count))
            }
        }

        return address
    }

    /// 기기의 현재 언어와 한국어를 기준으로 국가명을 가져온다
    private static let countryPrefixes: [String] = {
        let locales = [
            Locale.current,
            Locale(identifier: "ko_KR")
        ]

        return Array(Set(locales.compactMap {
            $0.localizedString(forRegionCode: "KR")
        })).map { $0 + " " }
    }()
}

// 현재 위치 주소

/// 현재 위치의 도로명 주소를 한 번 가져온다
enum CurrentAddress {
    private static let timeoutSeconds: UInt64 = 10

    /// 위치 권한을 허용하지 않았거나 주소를 찾지 못하면 nil
    static func fetch() async -> String? {
        await withTaskGroup(of: String?.self) { group in
            // 현재 위치 및 주소 요청
            group.addTask {
                await fetchLocation()
            }

            // 최대 10초 대기
            group.addTask {
                try? await Task.sleep(
                    for: .seconds(timeoutSeconds)
                )
                return nil
            }

            let result = await group.next() ?? nil

            // 먼저 완료된 작업의 결과를 사용하고 나머지는 취소
            group.cancelAll()
            return result
        }
    }

    private static func fetchLocation() async -> String? {
        let manager = CLLocationManager()

        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }

        let session = CLServiceSession(
            authorization: .whenInUse
        )

        defer {
            session.invalidate()
            _ = manager
        }

        do {
            for try await update in CLLocationUpdate.liveUpdates() {
                if Task.isCancelled {
                    return nil
                }

                if update.authorizationDenied ||
                    update.authorizationDeniedGlobally ||
                    update.authorizationRestricted {
                    return nil
                }

                if let location = update.location {
                    return await address(of: location)
                }
            }
        } catch {
            if !Task.isCancelled {
                print("위치 오류:", error)
            }
        }

        return nil
    }

    private static func address(
        of location: CLLocation
    ) async -> String? {
        guard let request = MKReverseGeocodingRequest(
            location: location
        ),
        let mapItem = try? await request.mapItems.first,
        let address = mapItem.address?.fullAddress else {
            return nil
        }

        return AddressSearch.removingCountry(address)
    }
}

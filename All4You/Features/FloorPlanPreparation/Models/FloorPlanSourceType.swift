//
//  FloorPlanSourceType.swift
//  All4You
//
//  Created by 채유성 on 11/1/26.
//

// 평면도 선택 타입
enum FloorPlanSourceType: String, Codable, CaseIterable, Identifiable, Hashable {
    case roomPlan
    case iPadDrawing
    case externalImport

    var id: Self { self }

    var title: String {
        switch self {
        case .roomPlan: "공간 스캔하기"
        case .iPadDrawing: "iPad에서 직접 그리기"
        case .externalImport: "외부 도면 가져오기"
        }
    }

    var description: String {
        switch self {
        case .roomPlan: "iPad 카메라로 현장 구조를 스캔해요"
        case .iPadDrawing: "손가락이나 Apple Pencil로 도면을 그려요"
        case .externalImport: "기존 스케치나 도면 이미지를 불러와 변환해요"
        }
    }
}

// 외부 도면 가져오기 - 사진 찍기, 사진 선택, 파일 첨부
enum ExternalImportType: String, Codable, CaseIterable, Identifiable, Hashable {
    case camera
    case photoLibrary
    case file

    var id: Self { self }

    var title: String {
        switch self {
        case .camera: "사진 찍기"
        case .photoLibrary: "사진 선택"
        case .file: "파일 첨부"
        }
    }
}

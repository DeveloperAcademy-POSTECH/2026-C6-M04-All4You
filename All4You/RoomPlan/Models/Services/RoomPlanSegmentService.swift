//
//  RoomPlanSegmentService.swift
//  All4You
//
//  Created by 채유성 on 11/3/26.
//

// CapturedRoomData와 CapturedRoom의 구간별 저장, StructureBuilder 기반 중간·최종 구조 병합을 담당하는 로직
import Foundation
import RoomPlan

struct RoomPlanSegmentService {
    enum SaveError: Error, Equatable {
        case emptyScan
    }

    let scanID = UUID()

    // 실시간 결과와 최종 처리 결과에 동일한 빈 공간 판정 적용
    static func hasScannedContent(_ room: CapturedRoom?) -> Bool {
        guard let room else { return false }
        return !room.walls.isEmpty || !room.floors.isEmpty
            || !room.objects.isEmpty || !room.doors.isEmpty
            || !room.windows.isEmpty || !room.openings.isEmpty
    }
    
    private var directory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RoomPlanScans", isDirectory: true)
            .appendingPathComponent(scanID.uuidString, isDirectory: true)
    }
    
    // 유실되는 데이터 없이 저장하기 위한 원시 AR 데이터의 비정상 부동소수점 값(이론상 무한대가 나올 수 있는 경우 등)을 허용하는 JSON 인코더 구성
    private func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: "Infinity",
            negativeInfinity: "-Infinity",
            nan: "NaN"
        )
        return encoder
    }
    
    // CapturedRoomData 원본 저장 및 RoomBuilder를 통한 가공 데이터(CapturedRoom) 생성
    func save(
        _ data: CapturedRoomData,
        index: Int,
        fallbackRoom: CapturedRoom?
    ) async throws -> SavedRoomPlanSegment {
        let room = (try? await RoomBuilder(options: [.beautifyObjects]).capturedRoom(from: data))
            ?? fallbackRoom
        // RoomBuilder가 빈 결과를 반환해도 원시 데이터만 저장 성공으로 처리하지 않음
        guard let room, Self.hasScannedContent(room) else {
            throw SaveError.emptyScan
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        
        let encoder = makeEncoder()
        // 원시(raw) 데이터와 가공(room) 데이터의 구간별 파일 경로 분리
        let rawURL = directory.appendingPathComponent("segment-\(index).raw.json")
        let roomURL = directory.appendingPathComponent("segment-\(index).room.json")
        
        do {
            // 1. 원시 센서 데이터(raw) 저장 시도
            try encoder.encode(data).write(to: rawURL, options: .atomic)
            
            // 원시 데이터 저장이 성공했다면, 가공 데이터 저장 실패는 프로세스를 중단하지 않는 부가 작업으로 취급 (크래시 방지)
            try? encoder.encode(room).write(to: roomURL, options: .atomic)
            return SavedRoomPlanSegment(url: rawURL, room: room)
        } catch let rawError {
            // 2. 원시 데이터 저장 실패 시, 가공 데이터라도 최대한 살려서 대체 저장 시도
            do {
                try encoder.encode(room).write(to: roomURL, options: .atomic)
                return SavedRoomPlanSegment(url: roomURL, room: room)
            } catch {
                throw SegmentWriteError(raw: rawError, room: error)
            }
        }
    }
    
    // 동일한 AR 좌표계의 CapturedRoom 배열을 하나의 3D 구조(CapturedStructure)로 병합
    func buildStructure(from rooms: [CapturedRoom]) async throws -> CapturedStructure {
        try await StructureBuilder(options: [.beautifyObjects])
            .capturedStructure(from: rooms)
    }

    // 한 구간은 CapturedRoom 자체를, 여러 구간은 병합된 CapturedStructure를 최종 결과로 저장
    func saveFinalModel(from rooms: [CapturedRoom], structure: CapturedStructure? = nil) async throws -> URL {
        if rooms.count == 1, let room = rooms.first {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let dataURL = directory.appendingPathComponent("final-room.json")
            try makeEncoder().encode(room).write(to: dataURL, options: .atomic)

            let modelURL = directory.appendingPathComponent("final-room.usdz")
            try room.export(to: modelURL)
            return modelURL
        }
        return try await saveMergedStructure(from: rooms, prebuiltStructure: structure)
    }
    
    // 최종 병합된 3D 구조의 JSON 및 USDZ 파일 내보내기
    func saveMergedStructure(
        from rooms: [CapturedRoom],
        prebuiltStructure: CapturedStructure? = nil
    ) async throws -> URL {
        let structure: CapturedStructure
        if let prebuiltStructure {
            structure = prebuiltStructure
        } else {
            structure = try await buildStructure(from: rooms)
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        
        let url = directory.appendingPathComponent("merged-structure.json")
        try makeEncoder().encode(structure).write(to: url, options: .atomic)
        
        // 병합 결과를 앱 내에서 3D 모델로 미리보기 위한 USDZ 파일 저장
        let modelURL = directory.appendingPathComponent("merged-structure.usdz")
        try structure.export(to: modelURL)
        return modelURL
    }
}

// 원시 데이터 및 가공 데이터 저장 실패 시 원인을 보존하기 위한 에러 타입
private struct SegmentWriteError: LocalizedError {
    let raw: Error
    let room: Error?
    
    var errorDescription: String? {
        if let room {
            return "원시 스캔과 공간 결과 저장에 모두 실패했습니다. (원시: \(raw.localizedDescription), 공간: \(room.localizedDescription))"
        }
        return "원시 스캔 저장에 실패했으며 변환할 공간 결과 데이터가 없습니다. (원시: \(raw.localizedDescription))"
    }
}

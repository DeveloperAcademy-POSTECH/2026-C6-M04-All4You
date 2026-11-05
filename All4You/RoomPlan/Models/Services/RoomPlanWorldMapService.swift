//
//  RoomPlanWorldMapService.swift
//  All4You
//
//  Created by 채유성 on 11/3/26.
//


// 사용자가 스캔한 공간 좌표 정보(ARWorldMap)를 기기 파일에 저장해 두었다가
// 나중에 연속해서 스캔을 이어갈 때 위치를 다시 잡기(Relocalization) 위해 꺼내다 주는 역할을 하는 ARWorldMap 저장소 로직
import ARKit
import Foundation

struct RoomPlanWorldMapService {
    let scanID: UUID

    // 아이폰 문서 폴더 안에 방 스캔 고유 ID별로 폴더를 만들고 최종적으로 'worldmap.arexperience'라는 이름의 파일로 저장될 위치를 지정
    private var url: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RoomPlanScans", isDirectory: true)
            .appendingPathComponent(scanID.uuidString, isDirectory: true)
            .appendingPathComponent("worldmap.arexperience")
    }

    // 공간 정보를 파일로 저장
    func save(_ map: ARWorldMap) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        let data = try NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true)
        try data.write(to: url, options: .atomic)
    }

    // 저장된 공간 정보 불러오기
    // 기기 안에 해당 파일이 실제로 존재하는지 먼저 확인한 뒤 파일이 있다면 압축되어 있던 데이터를 다시 원래의 ARWorldMap 공간 객체 형태로 복원하여 돌려줌
    func load() throws -> ARWorldMap? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: Data(contentsOf: url))
    }
}

//
//  FloorPlanMemoTaggedContent.swift
//  All4You
//
//  Created by 채유성 on 11/13/26.
//


// 메모 본문 사진 태그 브랜드 색 적용 및 눌렀을 때 연결된 사진 미리보기
import SwiftUI

struct FloorPlanMemoTaggedContent: View {
    let memo: FloorPlanMemo
    let bookmarkedPhotos: [LoadedPhoto]
    let onPhotoTap: (LoadedPhoto) -> Void
    
    var body: some View {
        Text(linkedContent)
            .font(AppTypography.headline)
            .tint(Color.brand500)
            .environment(\.openURL, OpenURLAction { url in
                guard url.scheme == "memo-photo",
                      let id = UUID(uuidString: url.host ?? ""),
                      let photo = memo.taggedPhotos.first(where: { $0.id == id }) else {
                    return .discarded
                }
                onPhotoTap(photo)
                return .handled
            })
    }
    
    private var linkedContent: AttributedString {
        let source = memo.content as NSString
        let matches = (try? NSRegularExpression(pattern: "#[1-9][0-9]*"))?
            .matches(in: memo.content, range: NSRange(location: 0, length: source.length)) ?? []
        let numberedPhotos = bookmarkedPhotos.sorted { $0.takenAt < $1.takenAt }
        let distinctTokens = matches.map { source.substring(with: $0.range) }.reduce(into: [String]()) { tokens, token in
            if !tokens.contains(token) { tokens.append(token) }
        }
        // 저장된 UUID 순서와 태그 순서가 일치하면 이후 북마크 번호가 바뀌어도 같은 사진을 연결
        let savedPhotosByToken: [String: LoadedPhoto] = distinctTokens.count == memo.taggedPhotos.count
        ? Dictionary(uniqueKeysWithValues: zip(distinctTokens, memo.taggedPhotos))
        : [:]
        var result = AttributedString()
        var cursor = 0
        var linkedTokens = Set<String>()
        
        for match in matches {
            result += AttributedString(source.substring(with: NSRange(location: cursor, length: match.range.location - cursor)))
            let token = source.substring(with: match.range)
            let number = Int(token.dropFirst()) ?? 0
            let photo = savedPhotosByToken[token]
            ?? linkedPhoto(number: number, numberedPhotos: numberedPhotos)
            
            if !linkedTokens.contains(token),
               let photo, let url = URL(string: "memo-photo://\(photo.id.uuidString)") {
                var linkedToken = AttributedString(token)
                linkedToken.foregroundColor = Color.brand500
                linkedToken.underlineStyle = .single
                linkedToken.link = url
                result += linkedToken
                linkedTokens.insert(token)
            } else {
                result += AttributedString(token)
            }
            cursor = NSMaxRange(match.range)
        }
        
        result += AttributedString(source.substring(from: cursor))
        return result
    }
    
    private func linkedPhoto(number: Int, numberedPhotos: [LoadedPhoto]) -> LoadedPhoto? {
        if number > 0, numberedPhotos.indices.contains(number - 1) {
            let numberedPhoto = numberedPhotos[number - 1]
            return memo.taggedPhotos.first(where: { $0.id == numberedPhoto.id })
        }
        return nil
    }
}

struct FloorPlanMemoPhotoPreview: View {
    @Environment(\.dismiss) private var dismiss
    let photo: LoadedPhoto
    
    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                Image(uiImage: photo.image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .background(.black)
            }
            .background(.black)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                }
            }
        }
        .presentationDetents([.large])
    }
}

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
        let matches = FloorPlanMemoPhotoTags.matches(in: memo, bookmarkedPhotos: bookmarkedPhotos)
        var result = AttributedString()
        var cursor = 0
        
        for match in matches {
            result += AttributedString(source.substring(with: NSRange(location: cursor, length: match.range.location - cursor)))
            let token = source.substring(with: match.range)
            
            if let photo = match.photo,
               let url = URL(string: "memo-photo://\(photo.id.uuidString)") {
                var linkedToken = AttributedString(token)
                linkedToken.foregroundColor = Color.brand500
                linkedToken.underlineStyle = .single
                linkedToken.link = url
                result += linkedToken
            } else {
                result += AttributedString(token)
            }
            cursor = NSMaxRange(match.range)
        }
        
        result += AttributedString(source.substring(from: cursor))
        return result
    }
}

/// 저장된 사진 UUID와 메모의 #번호를 연결해 두 화면에서 같은 태그를 표시
enum FloorPlanMemoPhotoTags {
    struct Match {
        let range: NSRange
        let photo: LoadedPhoto?
    }
    
    static func matches(in memo: FloorPlanMemo, bookmarkedPhotos: [LoadedPhoto]) -> [Match] {
        let source = memo.content as NSString
        let matches = (try? NSRegularExpression(pattern: "#[1-9][0-9]*"))?
            .matches(in: memo.content, range: NSRange(location: 0, length: source.length)) ?? []
        let numberedPhotos = bookmarkedPhotos.sorted { $0.takenAt < $1.takenAt }
        let distinctTokens = matches.map { source.substring(with: $0.range) }.reduce(into: [String]()) { tokens, token in
            if !tokens.contains(token) { tokens.append(token) }
        }
        let savedPhotosByToken: [String: LoadedPhoto] = distinctTokens.count == memo.taggedPhotos.count
        ? Dictionary(uniqueKeysWithValues: zip(distinctTokens, memo.taggedPhotos))
        : [:]
        var linkedTokens = Set<String>()
        
        return matches.map { match in
            let token = source.substring(with: match.range)
            let number = Int(token.dropFirst()) ?? 0
            let fallbackPhoto: LoadedPhoto? = if number > 0, numberedPhotos.indices.contains(number - 1) {
                memo.taggedPhotos.first(where: { $0.id == numberedPhotos[number - 1].id })
            } else {
                nil
            }
            let photo = linkedTokens.insert(token).inserted
            ? (savedPhotosByToken[token] ?? fallbackPhoto)
            : nil
            return Match(range: match.range, photo: photo)
        }
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

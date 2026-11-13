// 치수선·면적 위에 얹는 글자. 이름 캡슐(공간·가구 라벨)과 헷갈리지 않게 캡슐 없이 주황 글자에 흰 윤곽만 둔다

import SwiftUI

/// 흰 윤곽이 있는 주황 글자. 뒤의 치수선이나 벽이 글자와 겹쳐도 읽힌다
struct DimensionTextView: View {
    /// 치수 글자 (예: "12.4㎡", "0.9×2m")
    let text: String
    /// 도면 확대·축소에 맞춰 키우고 줄이는 배율 (LabelScale). 1이면 기본 크기
    var scale: CGFloat = 1
    /// 글자 색. 치수 종류마다 다르다 (DimensionKind.color)
    var color: Color = .orange700

    var body: some View {
        Text(text)
            .font(AppTypography.label.weight(.semibold))
            .foregroundStyle(color)
            .fixedSize()
            // 흰 윤곽: 같은 글자를 흰색으로 사방에 겹쳐 둔다
            .background {
                ForEach(Self.haloOffsets.indices, id: \.self) { index in
                    Text(text)
                        .font(AppTypography.label.weight(.semibold))
                        .foregroundStyle(.white)
                        .fixedSize()
                        .offset(Self.haloOffsets[index])
                }
            }
            .scaleEffect(scale)
    }

    /// 윤곽을 만드는 흰 글자의 어긋난 자리 (pt)
    static let haloOffsets: [CGSize] = [
        CGSize(width: 2, height: 0), CGSize(width: -2, height: 0), CGSize(width: 0, height: 2), CGSize(width: 0, height: -2),
        CGSize(width: 1.5, height: 1.5), CGSize(width: -1.5, height: 1.5), CGSize(width: 1.5, height: -1.5), CGSize(width: -1.5, height: -1.5),
    ]
}

#Preview {
    DimensionTextView(text: "12.4㎡")
        .padding()
        .background(.gray100)
}

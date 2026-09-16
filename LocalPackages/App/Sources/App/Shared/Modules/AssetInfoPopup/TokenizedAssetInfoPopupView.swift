import SwiftUI
import TKLocalize

enum TokenizedAssetInfoKind {
    case stock
    case etf

    var badgeTitle: String {
        switch self {
        case .stock:
            TKLocales.Trade.AssetDetails.Tokenized.Stock.badge
        case .etf:
            TKLocales.Trade.AssetDetails.Tokenized.Etf.badge
        }
    }

    private var title: String {
        switch self {
        case .stock:
            TKLocales.Trade.AssetDetails.Tokenized.Stock.title
        case .etf:
            TKLocales.Trade.AssetDetails.Tokenized.Etf.title
        }
    }

    private var caption: String {
        switch self {
        case .stock:
            TKLocales.Trade.AssetDetails.Tokenized.Stock.caption
        case .etf:
            TKLocales.Trade.AssetDetails.Tokenized.Etf.caption
        }
    }

    private var bullets: [String] {
        switch self {
        case .stock:
            [
                TKLocales.Trade.AssetDetails.Tokenized.Stock.pointOne,
                TKLocales.Trade.AssetDetails.Tokenized.Stock.pointTwo,
                TKLocales.Trade.AssetDetails.Tokenized.Stock.pointThree,
            ]
        case .etf:
            [
                TKLocales.Trade.AssetDetails.Tokenized.Etf.pointOne,
                TKLocales.Trade.AssetDetails.Tokenized.Etf.pointTwo,
                TKLocales.Trade.AssetDetails.Tokenized.Etf.pointThree,
            ]
        }
    }

    fileprivate var content: BulletsInfoPopupContent {
        BulletsInfoPopupContent(
            title: title,
            caption: caption,
            captionStyle: .body2,
            bullets: bullets
        )
    }
}

struct TokenizedAssetInfoPopupView: View {
    let kind: TokenizedAssetInfoKind
    let dismiss: () -> Void

    var body: some View {
        BulletsInfoPopupView(content: kind.content, onPrimaryTap: dismiss)
    }
}

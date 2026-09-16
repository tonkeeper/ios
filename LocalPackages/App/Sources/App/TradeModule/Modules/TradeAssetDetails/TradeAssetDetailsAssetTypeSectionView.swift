import KeeperCore
import SwiftUI
import TKLocalize
import TKUIKit

enum TradeAssetDetailsAssetTypeSectionKind {
    case tokenizedStock
    case tokenizedEtf
    case unverified

    init?(assetInfo: TradingAssetInfo) {
        if assetInfo.isUnverified {
            self = .unverified
        } else if let kind = assetInfo.category.tokenizedAssetInfoKind {
            switch kind {
            case .stock:
                self = .tokenizedStock
            case .etf:
                self = .tokenizedEtf
            }
        } else {
            return nil
        }
    }
}

struct TradeAssetDetailsAssetTypeSectionView: View {
    @Environment(\.tkPalette) private var palette
    var kind: TradeAssetDetailsAssetTypeSectionKind
    var onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: Layout.spacing) {
                Text(title)
                    .textStyle(.body2)
                    .foregroundStyle(tint)

                SwiftUI.Image.TKUIKit.Icons.Size12.chevronRight
                    .foregroundStyle(tint)
            }
            .frame(height: Layout.height)
            .frame(maxWidth: .infinity, alignment: .center)
            .background(background)
        }
    }

    private var background: Color {
        switch kind {
        case .tokenizedStock, .tokenizedEtf:
            palette.accent.blue.opacity(0.08)
        case .unverified:
            palette.accent.orange.opacity(0.08)
        }
    }

    private var tint: Color {
        switch kind {
        case .tokenizedStock, .tokenizedEtf:
            palette.accent.blue
        case .unverified:
            palette.accent.orange
        }
    }

    private var title: String {
        switch kind {
        case .tokenizedStock:
            TKLocales.Trade.AssetDetails.AssetType.tokenizedStock
        case .tokenizedEtf:
            TKLocales.Trade.AssetDetails.AssetType.tokenizedEtf
        case .unverified:
            TKLocales.Trade.AssetDetails.AssetType.unverified
        }
    }
}

extension TradeAssetDetailsAssetTypeSectionView {
    enum Layout {
        static let height: CGFloat = 32
        static let spacing: CGFloat = 4
    }
}

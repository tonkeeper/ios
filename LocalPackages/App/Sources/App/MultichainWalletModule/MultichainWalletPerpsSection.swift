import Perps
import SwiftUI
import TKLocalize
import TKUIKit

struct MultichainWalletPerpsSection: View {
    enum Placement {
        case aboveAssets
        case belowAssets
    }

    let placement: Placement
    @ObservedObject var viewModel: MultichainWalletPerpsSectionViewModel

    var body: some View {
        content
    }

    @ViewBuilder
    private var content: some View {
        switch placement {
        case .aboveAssets:
            if case let .positions(positions) = viewModel.content {
                positionsSection(positions)
            }
        case .belowAssets:
            if case let .shelf(markets) = viewModel.content {
                shelfSection(markets)
            }
        }
    }

    private func positionsSection(_ positions: [PerpsPositionRowItem]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ListTitleView(config: .text(
                TKLocales.Perps.title,
                accessory: balanceAccessory,
                titleAction: viewModel.openPerps
            ))

            PerpsOpenPositionsCard(
                positions: positions,
                onSelect: viewModel.openMarket
            )
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.bottom, Layout.sectionBottomPadding)
    }

    private func shelfSection(_ markets: [PerpsShelfMarketViewData]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ListTitleView(config: .text(
                TKLocales.Perps.title,
                accessory: balanceAccessory,
                titleAction: viewModel.openPerps
            ))
            .padding(.horizontal, Layout.horizontalPadding)

            MultichainWalletPerpsShelfView(
                markets: markets,
                onOpenMarket: viewModel.openMarket
            )
        }
        .padding(.bottom, Layout.sectionBottomPadding)
    }

    private var balanceAccessory: ListTitleView.Accessory? {
        viewModel.balanceText.map { balanceText in
            ListTitleView.Accessory(
                title: balanceText,
                icon: .TKUIKit.Icons.Size16.walletOutline,
                foregroundColor: .textSecondary,
                textStyle: .label2,
                action: viewModel.openPerps
            )
        }
    }
}

private extension MultichainWalletPerpsSection {
    enum Layout {
        static let horizontalPadding: CGFloat = 16
        static let sectionBottomPadding: CGFloat = 16
    }
}

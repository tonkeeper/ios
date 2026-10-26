import PerpsModels
import SwiftUI
import TKUIKit

private final class PerpsRootPreviewViewModel: PerpsRootViewModeling {
    let accountState: PerpsRootAccountState
    let marketsState: PerpsRootMarketsState
    let sort: PerpsMarketsSort = .volume
    let fundingToast: PerpsAssetPageTradeToast?
    let zeroBalanceText = "$0.00"

    let onBack: (() -> Void)? = {}
    let onLearnBasics: (() -> Void)? = {}
    let onSearch: (() -> Void)? = {}
    let onHistory: (() -> Void)? = {}
    let onDeposit: (() -> Void)? = {}
    let onWithdraw: (() -> Void)? = {}

    init(
        accountState: PerpsRootAccountState,
        marketsState: PerpsRootMarketsState,
        fundingToast: PerpsAssetPageTradeToast? = nil
    ) {
        self.accountState = accountState
        self.marketsState = marketsState
        self.fundingToast = fundingToast
    }

    func onAppear() {}
    func onDisappear() {}
    func openFundingToast() {}
    func setSort(_: PerpsMarketsSort) {}
    func selectMarket(_: Int64) {}
    func rowAppeared(_: Int64) {}
    func rowDisappeared(_: Int64) {}
}

private let previewMarkets = [
    PerpsMarketRowItem(
        id: 1,
        symbol: "BTC",
        iconURL: nil,
        leverageText: "40X",
        volumeText: "$1.24B VOL",
        priceText: "$67,104.20",
        changeText: "+3.84%",
        isChangePositive: true
    ),
    PerpsMarketRowItem(
        id: 2,
        symbol: "ETH",
        iconURL: nil,
        leverageText: "25X",
        volumeText: "$684.1M VOL",
        priceText: "$3,481.09",
        changeText: "−1.12%",
        isChangePositive: false
    ),
    PerpsMarketRowItem(
        id: 3,
        symbol: "TON",
        iconURL: nil,
        leverageText: "10X",
        volumeText: "$42.7M VOL",
        priceText: "$5.68",
        changeText: "+0.42%",
        isChangePositive: true
    ),
]

private let previewPortfolio = PerpsRootAccountState.Portfolio(
    accountIndex: 0,
    balanceText: "$1,284.60",
    positions: [
        PerpsPositionRowItem(
            id: 1,
            symbol: "BTC",
            iconURL: nil,
            leverageText: "27X",
            sideText: "LONG",
            isLong: true,
            valueText: "$540.00",
            pnlText: "+ $18.24",
            isPnlPositive: true
        ),
        PerpsPositionRowItem(
            id: 2,
            symbol: "ETH",
            iconURL: nil,
            leverageText: "10X",
            sideText: "SHORT",
            isLong: false,
            valueText: "$212.40",
            pnlText: "− $6.03",
            isPnlPositive: false
        ),
    ],
    positionsTotal: PerpsPositionsTotal(
        amountText: "$752.40",
        pnlText: "+ $12.21",
        pnlPercentText: "+1.65%",
        isPnlPositive: true
    ),
    limitOrders: [
        PerpsLimitOrderRowItem(
            orderIndex: 844_421_356_582_789,
            marketId: 1,
            symbol: "BTC",
            iconURL: nil,
            sideText: "LONG",
            isLong: true,
            valueText: "$18.81",
            limitText: "Limit $81,799.20"
        ),
        PerpsLimitOrderRowItem(
            orderIndex: 844_421_356_582_790,
            marketId: 3,
            symbol: "TON",
            iconURL: nil,
            sideText: "SHORT",
            isLong: false,
            valueText: "$40.00",
            limitText: "Limit $6.10"
        ),
    ]
)

#Preview("Deep Blue") {
    PerpsRootView(
        viewModel: PerpsRootPreviewViewModel(
            accountState: .active(previewPortfolio),
            marketsState: .loaded(items: previewMarkets, isLoadingNextPage: false)
        )
    )
    .tkPreviewTheme(.deepBlue)
}

#Preview("Pending deposit") {
    PerpsRootView(
        viewModel: PerpsRootPreviewViewModel(
            accountState: .inactive,
            marketsState: .loaded(items: previewMarkets, isLoadingNextPage: false),
            fundingToast: .progress("Sending transaction")
        )
    )
    .tkPreviewTheme(.deepBlue)
}

#Preview("No account") {
    PerpsRootView(
        viewModel: PerpsRootPreviewViewModel(
            accountState: .inactive,
            marketsState: .loaded(items: previewMarkets, isLoadingNextPage: true)
        )
    )
    .tkPreviewTheme(.deepBlue)
}

#Preview("Light") {
    PerpsRootView(
        viewModel: PerpsRootPreviewViewModel(
            accountState: .active(previewPortfolio),
            marketsState: .loaded(items: previewMarkets, isLoadingNextPage: false)
        )
    )
    .tkPreviewTheme(.light)
}

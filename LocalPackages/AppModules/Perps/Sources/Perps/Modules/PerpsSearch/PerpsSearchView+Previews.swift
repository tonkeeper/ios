import PerpsModels
import SwiftUI
import TKUIKit

private final class PerpsSearchPreviewViewModel: PerpsSearchViewModeling {
    @Published var searchText: String
    let sort: PerpsMarketsSort = .volume
    @Published var filter: PerpsMarketFilter = .all
    let marketsState: PerpsSearchMarketsState
    let isSearchFocusRequested = false
    let onBack: (() -> Void)? = {}

    init(searchText: String, marketsState: PerpsSearchMarketsState, filter: PerpsMarketFilter = .all) {
        self.filter = filter
        self.searchText = searchText
        self.marketsState = marketsState
    }

    func onAppear() {}
    func onDisappear() {}
    func requestSearchFocus() {}
    func updateSearchText(_ value: String) {
        searchText = value
    }

    func setSort(_: PerpsMarketsSort) {}
    func setFilter(_ filter: PerpsMarketFilter) {
        self.filter = filter
    }

    func selectMarket(_: Int64) {}
    func rowAppeared(_: Int64) {}
    func rowDisappeared(_: Int64) {}
    func retry() {}
}

private let previewResults = [
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
]

#Preview("Results") {
    PerpsSearchView(
        viewModel: PerpsSearchPreviewViewModel(
            searchText: "",
            marketsState: .loaded(items: previewResults, isLoadingNextPage: false)
        )
    )
    .tkPreviewTheme(.deepBlue)
}

#Preview("Empty") {
    PerpsSearchView(
        viewModel: PerpsSearchPreviewViewModel(
            searchText: "zzz",
            marketsState: .empty,
            filter: .etfs
        )
    )
    .tkPreviewTheme(.deepBlue)
}

#Preview("Commodities") {
    PerpsSearchView(viewModel: PerpsSearchPreviewViewModel(searchText: "", marketsState: .empty, filter: .commodities))
        .tkPreviewTheme(.deepBlue)
}

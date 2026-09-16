import BigInt
import Foundation
import KeeperCore
import TKLocalize
import TKLogging
import TKUIKit
import UIKit

@MainActor
final class TradeAssetsListQueryViewModel: ObservableObject {
    private enum Constants {
        static let loadMoreThreshold = 5
    }

    struct RowData: Equatable {
        var assets: [TradingAsset]
        var currency: Currency
        var hasNextPage: Bool?

        static var initial: RowData {
            RowData(
                assets: [],
                currency: .USD,
                hasNextPage: nil
            )
        }
    }

    enum State {
        case idle
        case refreshing(
            rowData: RowData,
            task: Task<Void, Never>
        )
        case loaded(
            rowData: RowData
        )
        case loadingMore(
            rowData: RowData,
            task: Task<Void, Never>
        )
        case failed(
            rowData: RowData,
            errorMessage: String?
        )
    }

    @Published private(set) var state: State

    private let query: String?
    private let category: TradingAssetCategory
    private let assetsListService: TradingAssetsListService
    private let amountFormatter: AmountFormatter
    private let signedAmountFormatter: AmountFormatter
    private let onWillPerformSearch: () -> Void

    init(
        query: String?,
        category: TradingAssetCategory,
        assetsListService: TradingAssetsListService,
        amountFormatter: AmountFormatter,
        signedAmountFormatter: AmountFormatter,
        onWillPerformSearch: @escaping () -> Void
    ) {
        self.query = query
        self.category = category
        self.assetsListService = assetsListService
        self.amountFormatter = amountFormatter
        self.signedAmountFormatter = signedAmountFormatter
        self.onWillPerformSearch = onWillPerformSearch
        self.state = .idle
    }

    func appeared() {
        switch state {
        case .idle:
            let task = Task {
                onWillPerformSearch()
                await loadFirstPage(fallbackData: .initial)
            }
            state = .refreshing(rowData: .initial, task: task)
        default:
            break
        }
    }

    func disappeared() {
        let rowDataToFallback: RowData
        switch state {
        case .idle:
            return
        case let .loaded(rowData), let .failed(rowData, _):
            rowDataToFallback = rowData
        case let .refreshing(rowData, task):
            task.cancel()
            rowDataToFallback = rowData
        case let .loadingMore(rowData, task):
            task.cancel()
            rowDataToFallback = rowData
        }
        if rowDataToFallback == .initial {
            state = .idle
        } else {
            state = .loaded(rowData: rowDataToFallback)
        }
    }

    func refresh() async {
        let rowData: RowData
        switch state {
        case let .loadingMore(data, task):
            task.cancel()
            rowData = data
        case .refreshing:
            return
        case let .failed(data, _):
            rowData = data
        case .idle:
            rowData = .initial
        case let .loaded(data):
            rowData = data
        }

        let task = Task {
            await loadFirstPage(fallbackData: rowData)
        }
        state = .refreshing(
            rowData: rowData,
            task: task
        )
        await task.value
    }

    func loadNextPageIfNeeded(currentAsset: TradingAsset) {
        guard case let .loaded(rowData) = state else {
            return
        }
        guard rowData.hasNextPage == true else {
            return
        }
        let currentIndex = rowData.assets.firstIndex {
            $0.id == currentAsset.id
        }
        guard let currentIndex else {
            return
        }

        let thresholdIndex = max(rowData.assets.count - Constants.loadMoreThreshold, 0)
        guard currentIndex >= thresholdIndex else {
            return
        }
        state = .loadingMore(
            rowData: rowData,
            task: Task {
                await loadNextPage(fallbackData: rowData)
            }
        )
    }

    func cellConfig(for asset: TradingAsset, currency: Currency) -> TradeAssetCellConfig {
        .content(
            TradeAssetCellContent(
                assetSymbol: asset.symbol,
                assetDisplayName: asset.subtitle,
                chainTag: AssetIdResolver.tag(
                    for: asset.id,
                    multichainEnabled: false
                ),
                iconImageSource: AssetIdResolver.imageSource(
                    for: asset.id,
                    imageUrl: asset.imageURL,
                    multichainEnabled: false
                ),
                priceText: formatPrice(
                    asset.price,
                    fractionDigits: asset.priceFractionDigits,
                    currency: currency
                ),
                changeText: formatChangeText(for: asset),
                showsVerificationCheckmark: asset.isTrusted
            )
        )
    }

    var emptyPlaceholderSubtitle: String {
        guard let query = query?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !query.isEmpty
        else {
            return TKLocales.Trade.Assets.Placeholder.empty
        }

        return TKLocales.Trade.Placeholder.noResultsForQuery(query)
    }
}

private extension TradeAssetsListQueryViewModel {
    func loadFirstPage(fallbackData: RowData) async {
        let snapshot: TradingAssetListSnapshot
        do {
            snapshot = try await assetsListService.load(
                query: query,
                category: category
            )
        } catch {
            guard !Task.isCancelled else {
                return
            }
            let errorMessage: String?
            switch error {
            case let .apiError(message):
                errorMessage = message
            case .networkError:
                errorMessage = TKLocales.ConnectionStatus.noInternet
            }
            state = .failed(
                rowData: fallbackData,
                errorMessage: errorMessage
            )
            return
        }
        guard !Task.isCancelled else {
            return
        }
        apply(snapshot)
    }

    func loadNextPage(fallbackData: RowData) async {
        let snapshot: TradingAssetListSnapshot?
        do {
            snapshot = try await assetsListService.loadNextPage(
                query: query,
                category: category
            )
        } catch {
            guard !Task.isCancelled else {
                return
            }
            let errorMessage: String?
            switch error {
            case let .apiError(message):
                errorMessage = message
            case .networkError:
                errorMessage = TKLocales.ConnectionStatus.noInternet
            }
            state = .failed(
                rowData: fallbackData,
                errorMessage: errorMessage
            )
            return
        }
        guard !Task.isCancelled else {
            return
        }
        guard let snapshot else {
            var data = fallbackData
            data.hasNextPage = false
            state = .loaded(rowData: data)
            return
        }
        apply(snapshot)
    }

    func apply(_ snapshot: TradingAssetListSnapshot) {
        state = .loaded(
            rowData: RowData(
                assets: snapshot.assets,
                currency: snapshot.currency,
                hasNextPage: snapshot.hasNextPage
            )
        )
    }

    func formatChangeText(for asset: TradingAsset) -> TradeAssetCellContent.ChangeText? {
        guard let title = formatChange(
            asset.change24hPercent,
            fractionDigits: asset.change24hPercentFractionDigits
        ) else {
            return nil
        }

        return TradeAssetCellContent.ChangeText(
            title: title,
            positive: asset.change24hPercent?.sign != .minus
        )
    }

    func formatPrice(_ price: BigInt?, fractionDigits: Int, currency: Currency) -> String {
        guard let price else {
            return "..."
        }

        return formattedBigInt(
            price,
            fractionDigits: fractionDigits,
            accessory: .fiat(currency)
        )
    }

    func formatChange(_ change24hPercent: BigInt?, fractionDigits: Int) -> String? {
        guard let change24hPercent else {
            return nil
        }

        return formattedBigInt(
            change24hPercent,
            fractionDigits: fractionDigits,
            formatter: signedAmountFormatter,
            style: .percent
        )
    }

    func formattedBigInt(
        _ value: BigInt,
        fractionDigits: Int,
        accessory: AmountAccessoryType = .none,
        formatter: AmountFormatter? = nil,
        style: AmountDisplayStyle = .compact
    ) -> String {
        let formatter = formatter ?? amountFormatter
        let magnitude = value.magnitude
        return formatter.format(
            amount: magnitude,
            fractionDigits: fractionDigits,
            accessory: accessory,
            isNegative: value.sign == .minus,
            style: style
        )
    }
}

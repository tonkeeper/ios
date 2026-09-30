import BigInt
import Foundation
import KeeperCore
import TKLocalize
import TKLogging
import TKUIKit

@MainActor
final class TokenPickerV2QueryViewModel: ObservableObject {
    private enum Constants {
        static let pageSize = 30
        static let loadMoreThreshold = 5
    }

    struct Item: Identifiable, Equatable {
        enum Payload: Equatable {
            case asset(MultichainAsset, row: AssetBalanceRowCellContent)
            case perp(PerpsMarketRowItem)
        }

        let payload: Payload

        var id: String {
            switch payload {
            case let .asset(_, row):
                row.id
            case let .perp(market):
                "perp_\(market.id)"
            }
        }

        var asset: MultichainAsset? {
            if case let .asset(asset, _) = payload {
                return asset
            }
            return nil
        }

        var assetRow: AssetBalanceRowCellContent? {
            if case let .asset(_, row) = payload {
                return row
            }
            return nil
        }
    }

    struct RowData: Equatable {
        var items: [Item]
        var nextCursor: String?
        var hasNextPage: Bool

        static var initial: RowData {
            RowData(items: [], nextCursor: nil, hasNextPage: false)
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

    enum Placeholder: Equatable {
        case empty
        case error(String?)
    }

    struct Presentation: Equatable {
        let items: [Item]
        let isLoadingMore: Bool
        let showsSkeleton: Bool
        let placeholder: Placeholder?
    }

    @Published private(set) var state: State = .idle

    private let query: String?
    private let category: TokenPickerV2ChainFilter
    private let displayMode: SendTokenV2PickerDisplayMode
    private let tokenPickerModel: any TokenPickerV2Model
    private let amountFormatter: AmountFormatter
    private let signedAmountFormatter: AmountFormatter
    private let currencyStore: CurrencyStore

    init(
        query: String?,
        category: TokenPickerV2ChainFilter,
        displayMode: SendTokenV2PickerDisplayMode,
        tokenPickerModel: any TokenPickerV2Model,
        amountFormatter: AmountFormatter,
        currencyStore: CurrencyStore
    ) {
        self.query = query
        self.category = category
        self.displayMode = displayMode
        self.tokenPickerModel = tokenPickerModel
        self.amountFormatter = amountFormatter
        var signedConfiguration = amountFormatter.config
        signedConfiguration.signPolicy = .always
        self.signedAmountFormatter = AmountFormatter(configuration: signedConfiguration)
        self.currencyStore = currencyStore
    }

    var presentation: Presentation {
        Self.presentation(for: state)
    }

    static func presentation(for state: State) -> Presentation {
        switch state {
        case .idle:
            return Presentation(
                items: [],
                isLoadingMore: false,
                showsSkeleton: true,
                placeholder: nil
            )
        case let .refreshing(rowData, _):
            if rowData == .initial {
                return Presentation(
                    items: [],
                    isLoadingMore: false,
                    showsSkeleton: true,
                    placeholder: nil
                )
            }
            return Presentation(
                items: rowData.items,
                isLoadingMore: false,
                showsSkeleton: false,
                placeholder: rowData.items.isEmpty ? .empty : nil
            )
        case let .loaded(rowData):
            return Presentation(
                items: rowData.items,
                isLoadingMore: false,
                showsSkeleton: false,
                placeholder: rowData.items.isEmpty ? .empty : nil
            )
        case let .loadingMore(rowData, _):
            return Presentation(
                items: rowData.items,
                isLoadingMore: true,
                showsSkeleton: rowData == .initial,
                placeholder: rowData.items.isEmpty ? .empty : nil
            )
        case let .failed(rowData, errorMessage):
            return Presentation(
                items: rowData.items,
                isLoadingMore: false,
                showsSkeleton: false,
                placeholder: rowData.items.isEmpty ? .error(errorMessage) : nil
            )
        }
    }

    func appeared() {
        switch state {
        case .idle:
            let task = Task {
                await loadFirstPage(fallbackData: .initial)
            }
            state = .refreshing(rowData: .initial, task: task)
        default:
            break
        }
    }

    func disappeared() {
        let fallbackData: RowData
        switch state {
        case .idle:
            return
        case let .loaded(rowData), let .failed(rowData, _):
            fallbackData = rowData
        case let .refreshing(rowData, task), let .loadingMore(rowData, task):
            task.cancel()
            fallbackData = rowData
        }

        if fallbackData == .initial {
            state = .idle
        } else {
            state = .loaded(rowData: fallbackData)
        }
    }

    func refresh() async {
        let rowData: RowData
        switch state {
        case .idle:
            rowData = .initial
        case let .loaded(data), let .failed(data, _):
            rowData = data
        case let .refreshing(data, task), let .loadingMore(data, task):
            task.cancel()
            rowData = data
        }

        let task = Task {
            await loadFirstPage(fallbackData: rowData)
        }
        state = .refreshing(rowData: rowData, task: task)
        await task.value
    }

    func loadNextPageIfNeeded(currentItem: Item) {
        guard case let .loaded(rowData) = state else {
            return
        }
        guard rowData.hasNextPage else {
            return
        }
        guard let currentIndex = rowData.items.firstIndex(where: { $0.id == currentItem.id }) else {
            return
        }

        let thresholdIndex = max(rowData.items.count - Constants.loadMoreThreshold, 0)
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

    func item(withID id: String) -> Item? {
        presentation.items.first(where: { $0.id == id })
    }
}

private extension TokenPickerV2QueryViewModel {
    func loadFirstPage(fallbackData: RowData) async {
        let result: TokenPickerLoadResult
        do {
            result = try await tokenPickerModel.loadAssets(
                query: query,
                filter: category,
                limit: Constants.pageSize,
                cursor: nil
            )
        } catch {
            guard !Task.isCancelled, !isCancelled(error) else {
                return
            }
            state = .failed(
                rowData: fallbackData,
                errorMessage: errorMessage(from: error)
            )
            return
        }

        guard !Task.isCancelled else {
            return
        }

        let assets = result.items
        state = .loaded(
            rowData: RowData(
                items: deduplicated(assets.map(makeItem)),
                nextCursor: result.nextCursor,
                hasNextPage: result.nextCursor != nil
            )
        )
    }

    func loadNextPage(fallbackData: RowData) async {
        let result: TokenPickerLoadResult
        do {
            result = try await tokenPickerModel.loadAssets(
                query: query,
                filter: category,
                limit: Constants.pageSize,
                cursor: fallbackData.nextCursor
            )
        } catch {
            guard !Task.isCancelled, !isCancelled(error) else {
                return
            }
            state = .failed(
                rowData: fallbackData,
                errorMessage: errorMessage(from: error)
            )
            return
        }

        guard !Task.isCancelled else {
            return
        }

        let mergedItems = deduplicated(
            merged(
                current: fallbackData.items,
                next: result.items.map(makeItem)
            )
        )
        state = .loaded(
            rowData: RowData(
                items: mergedItems,
                nextCursor: result.nextCursor,
                hasNextPage: result.nextCursor != nil
            )
        )
    }

    func merged(
        current: [Item],
        next: [Item]
    ) -> [Item] {
        var mergedItems = current
        var indexesByID = Dictionary(
            mergedItems.enumerated()
                .map {
                    ($0.element.id, $0.offset)
                }
        ) { first, _ in
            first
        }

        for item in next {
            if let index = indexesByID[item.id] {
                mergedItems[index] = item
            } else {
                indexesByID[item.id] = mergedItems.count
                mergedItems.append(item)
            }
        }

        return mergedItems
    }

    /// `ForEach(id:)` in `TokenPickerV2View` requires unique ids to lay out rows correctly;
    /// duplicate ids (seen from overlapping catalog pages) desync SwiftUI's row diffing from
    /// the row-rounding math, which shows up as broken/duplicated corners mid-list.
    func deduplicated(_ items: [Item]) -> [Item] {
        var seenIDs = Set<String>()
        var result = [Item]()
        result.reserveCapacity(items.count)
        for item in items {
            guard seenIDs.insert(item.id).inserted else {
                Log.w("TokenPickerV2: dropping duplicate asset id \(item.id)")
                continue
            }
            result.append(item)
        }
        return result
    }

    func makeItem(asset: TokenPickerLoadResult.Item) -> Item {
        switch asset {
        case let .perp(market):
            return Item(payload: .perp(PerpsMarketRowMapping.item(from: market)))
        case let .asset(asset):
            let badge = category == .all
                ? AssetIdResolver.tag(for: asset.asset.assetId, multichainEnabled: true)
                : nil

            return Item(
                payload: .asset(
                    asset,
                    row: AssetBalanceRowCellContent(
                        id: asset.asset.assetId,
                        title: title(for: asset),
                        badge: badge,
                        displayMode: rowDisplayMode(for: asset),
                        avatarImageSource: AssetIdResolver.imageSource(
                            for: asset.asset.assetId,
                            imageUrl: URL(string: asset.asset.image),
                            multichainEnabled: true
                        ),
                        showsVerificationCheckmark: asset.asset.isTrusted,
                        accessibilityIdentifier: accessibilityIdentifier(for: asset)
                    )
                )
            )
        }
    }

    func title(for asset: MultichainAsset) -> String {
        asset.asset.symbol.isEmpty ? asset.asset.name : asset.asset.symbol
    }

    func accessibilityIdentifier(for asset: MultichainAsset) -> String {
        let symbol = title(for: asset)
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "_", options: .regularExpression)
        guard let chain = asset.asset.chain else {
            return "token_picker_asset_\(symbol)"
        }
        return "token_picker_asset_\(chain.rawValue)_\(symbol)"
    }

    func rowDisplayMode(for asset: MultichainAsset) -> AssetBalanceRowCellContent.DisplayMode {
        let currency = currencyStore.state
        switch displayMode {
        case .includingMarketData:
            let change = formatChange(asset.price.diff24h, currency: currency)
            return .includingMarketData(
                marketCap: formatMarketCap(asset),
                price: formatPrice(asset),
                change: change,
                showsPin: false
            )
        case let .includingSelection(selectedAsset):
            return .includingSelection(
                balance: formatSelectionBalance(asset),
                fiat: formatFiatValue(asset),
                showsPin: selectedAsset?.asset.assetId == asset.asset.assetId
            )
        case .rampAsset:
            return .rampAsset(subtitle: asset.asset.name)
        }
    }

    func formatSelectionBalance(_ asset: MultichainAsset) -> String {
        let symbol = asset.asset.symbol.isEmpty ? asset.asset.name : asset.asset.symbol
        return amountFormatter.format(
            amount: asset.balance,
            fractionDigits: asset.asset.decimals,
            accessory: .tokenSymbol(symbol),
            style: .compact
        )
    }

    func formatPrice(_ asset: MultichainAsset) -> String {
        let currency = currencyStore.state
        guard let price = decimalValue(
            in: asset.price.prices,
            currency: currency
        ) else {
            return "..."
        }

        return amountFormatter.format(
            decimal: price,
            accessory: AmountAccessoryType(currency: currency),
            style: .compact
        )
    }

    func formatMarketCap(_ asset: MultichainAsset) -> String {
        let currency = currencyStore.state
        let amount: Decimal
        let formatCurrency: Currency
        if let value = decimalValue(
            in: asset.marketCap,
            currency: currency
        ) {
            amount = value
            formatCurrency = currency
        } else if let value = decimalValue(
            in: asset.marketCap,
            currency: .defaultCurrency
        ) {
            amount = value
            formatCurrency = .defaultCurrency
        } else {
            return "..."
        }

        let formatted = formatAbbreviatedMarketCap(amount: amount, currency: formatCurrency)
        return "\(formatted) \(TKLocales.TokensPicker.marketCapSuffix)"
    }

    private func formatAbbreviatedMarketCap(amount: Decimal, currency: Currency) -> String {
        let magnitude = abs(amount)
        let doubleValue = NSDecimalNumber(decimal: magnitude).doubleValue
        guard doubleValue.isFinite else {
            return amountFormatter.format(
                decimal: magnitude,
                accessory: AmountAccessoryType(currency: currency),
                style: .compact
            )
        }

        let compactNumber = doubleValue.formatted(
            FloatingPointFormatStyle<Double>.number
                .locale(amountFormatter.config.locale)
                .notation(.compactName)
                .precision(.fractionLength(0 ... 2))
                .rounded(rule: .down)
        )

        let space = amountFormatter.config.space
        return currency.symbolOnLeft
            ? "\(currency.symbol)\(space)\(compactNumber)"
            : "\(compactNumber)\(space)\(currency.symbol)"
    }

    func formatFiatValue(_ asset: MultichainAsset) -> String {
        let currency = currencyStore.state
        let fiatValue = convertedAmount(
            for: asset,
            currency: currency
        ) ?? .zero

        return amountFormatter.format(
            decimal: fiatValue,
            accessory: AmountAccessoryType(currency: currency),
            style: .fiatBalance
        )
    }

    func formatChange(
        _ values: [String: String],
        currency: Currency
    ) -> AssetBalanceRowCellContent.Delta? {
        guard let rawValue = lookupValue(in: values, currency: currency) else {
            return nil
        }
        guard let decimal = decimalValue(from: rawValue) else {
            return AssetBalanceRowCellContent.Delta(
                text: rawValue,
                isPositive: !rawValue.hasNegativePrefix
            )
        }

        return AssetBalanceRowCellContent.Delta(
            text: signedAmountFormatter.format(decimal: decimal, style: .percent),
            isPositive: decimal >= 0
        )
    }

    func convertedAmount(
        for asset: MultichainAsset,
        currency: Currency
    ) -> Decimal? {
        guard let price = decimalValue(
            in: asset.price.prices,
            currency: currency
        ) else {
            return nil
        }

        return decimalAmount(
            balance: asset.balance,
            fractionDigits: asset.asset.decimals
        ) * price
    }

    func decimalAmount(
        balance: BigUInt,
        fractionDigits: Int
    ) -> Decimal {
        guard let amount = Decimal(
            string: balance.description,
            locale: Locale(identifier: "en_US_POSIX")
        ) else {
            return .zero
        }
        guard fractionDigits > 0 else {
            return amount
        }

        return amount / powerOfTen(fractionDigits)
    }

    func powerOfTen(_ exponent: Int) -> Decimal {
        guard exponent > 0 else {
            return 1
        }

        var result = Decimal(1)
        for _ in 0 ..< exponent {
            result *= 10
        }
        return result
    }

    func decimalValue(
        in values: [String: Double],
        currency: Currency
    ) -> Decimal? {
        guard let value = lookupValue(in: values, currency: currency),
              value.isFinite
        else {
            return nil
        }

        return NSDecimalNumber(value: value).decimalValue
    }

    func decimalValue(
        in values: [String: String],
        currency: Currency
    ) -> Decimal? {
        lookupValue(in: values, currency: currency)
            .flatMap(decimalValue(from:))
    }

    func lookupValue<Value>(
        in values: [String: Value],
        currency: Currency
    ) -> Value? {
        let code = currency.code
        return values[code.lowercased()]
            ?? values[code.uppercased()]
            ?? values[code]
    }

    func decimalValue(from value: String) -> Decimal? {
        let normalized = value
            .replacingOccurrences(of: String.Symbol.minus, with: "-")
            .replacingOccurrences(of: String.Symbol.plus, with: "+")
            .filter { "0123456789.,+-".contains($0) }

        guard !normalized.isEmpty else {
            return nil
        }

        let signedNormalized = normalized.dropFirstSign()
        guard signedNormalized.value.contains(where: { "0123456789".contains($0) }) else {
            return nil
        }

        let decimalSeparatorIndex = signedNormalized.value.lastIndex {
            $0 == "." || $0 == ","
        }

        let decimalString: String
        if let decimalSeparatorIndex {
            let integer = signedNormalized.value[..<decimalSeparatorIndex]
                .filter { "0123456789".contains($0) }
            let fraction = signedNormalized.value[signedNormalized.value.index(after: decimalSeparatorIndex)...]
                .filter { "0123456789".contains($0) }
            let integerPart = integer.isEmpty ? "0" : integer
            decimalString = signedNormalized.sign + integerPart + (fraction.isEmpty ? "" : "." + fraction)
        } else {
            decimalString = signedNormalized.sign + signedNormalized.value
        }

        return Decimal(
            string: decimalString,
            locale: Locale(identifier: "en_US_POSIX")
        )
    }

    func isCancelled(_ error: MultichainServiceError) -> Bool {
        if case .cancelled = error {
            return true
        }
        return false
    }

    func errorMessage(from error: MultichainServiceError) -> String? {
        switch error {
        case .cancelled:
            return nil
        case .connectionError:
            return TKLocales.ConnectionStatus.noInternet
        case let .apiError(message):
            return message
        }
    }
}

private extension String {
    var hasNegativePrefix: Bool {
        hasPrefix("-") || hasPrefix(String.Symbol.minus)
    }

    func dropFirstSign() -> (sign: String, value: String) {
        guard let first else {
            return ("", self)
        }

        switch first {
        case "-", "+":
            return (String(first), String(dropFirst()))
        default:
            return ("", self)
        }
    }
}

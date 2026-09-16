import Combine
import Foundation
import KeeperCore
import TKLogging
import TronSwift
import UIKit

struct TradeAssetDetailsMarketData {
    let priceText: String
    let changeText: String?
    let changeAmountText: String?
    let changeColor: UIColor
}

@MainActor
final class TradeAssetDetailsMarketDataViewModel: ObservableObject {
    @Published private(set) var state: TradeAssetDetailsMarketData?

    private let typedAssetId: TradingAssetToken?
    private let ratesService: RatesService
    private let currencyStore: CurrencyStore
    private let valueFormatter: TradeAssetDetailsValueFormatter

    private var task: Task<Void, Never>?

    init(
        typedAssetId: TradingAssetToken?,
        ratesService: RatesService,
        currencyStore: CurrencyStore,
        amountFormatter: AmountFormatter,
        signedAmountFormatter: AmountFormatter
    ) {
        self.typedAssetId = typedAssetId
        self.ratesService = ratesService
        self.currencyStore = currencyStore
        self.valueFormatter = TradeAssetDetailsValueFormatter(
            amountFormatter: amountFormatter,
            signedAmountFormatter: signedAmountFormatter,
            currencyProvider: { [currencyStore] in
                currencyStore.state
            }
        )
    }

    deinit {
        task?.cancel()
    }

    func scheduleUpdate() {
        primeCache()
        reload()
    }
}

private extension TradeAssetDetailsMarketDataViewModel {
    func primeCache() {
        guard let cached = cachedMarketData() else {
            return
        }
        state = cached
    }

    func reload() {
        task?.cancel()
        task = Task { [weak self] in
            await self?.refresh()
        }
    }

    func refresh() async {
        do {
            let marketData = try await loadMarketData()
            guard !Task.isCancelled else {
                return
            }
            state = marketData
        } catch {
            Log.i("market data load failed, skip update, error: \(error)")
        }
    }
}

private extension TradeAssetDetailsMarketDataViewModel {
    func cachedMarketData() -> TradeAssetDetailsMarketData? {
        nil
    }

    func loadMarketData() async throws -> TradeAssetDetailsMarketData? {
        guard let rateIdentifier = typedAssetId else {
            return nil
        }

        let currency = currencyStore.state

        let rates: Rates
        switch rateIdentifier {
        case .ton, .tronUsdt:
            rates = try await ratesService.loadRates(
                jettons: [],
                currencies: [currency]
            )
        case .tronTrx:
            rates = try await ratesService.loadRates(
                jettons: [TRX.symbol],
                currencies: [currency]
            )
        case let .jetton(address):
            if address == JettonMasterAddress.tonUSDT {
                rates = try await ratesService.loadRates(
                    jettons: [],
                    currencies: [currency]
                )
            } else {
                rates = try await ratesService.loadRates(
                    jettons: [address.toRaw()],
                    currencies: [currency]
                )
            }
        }

        guard let rate = rates.rate(for: rateIdentifier, in: currency) else {
            return nil
        }

        let changePercent = rate.diff24h.flatMap { valueFormatter.decimalValue($0) }
        let changeColor = (changePercent ?? 0) < 0 ? UIColor.Accent.red : .Accent.green

        return TradeAssetDetailsMarketData(
            priceText: valueFormatter.formatPrice(rate.rate),
            changeText: changePercent.map(valueFormatter.formatChange),
            changeAmountText: changePercent
                .flatMap {
                    valueFormatter.calculateChangeAmount(
                        price: rate.rate,
                        diffPercent: $0
                    )
                }
                .map(valueFormatter.formatSignedPrice),
            changeColor: changeColor
        )
    }
}

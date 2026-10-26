import BigInt
import Foundation
import KeeperCore
import TKLogging

struct LegacyPairMultichainSwapDefaultAssetsService: MultichainSwapDefaultAssetsService {
    private let wallet: Wallet
    private let sendAssetId: String
    private let receiveAssetId: String
    private let assetDetailsService: TradingAssetDetailsService
    private let convertedBalanceStore: ConvertedBalanceStore
    private let currencyStore: CurrencyStore

    init(
        wallet: Wallet,
        sendAssetId: String,
        receiveAssetId: String,
        assetDetailsService: TradingAssetDetailsService,
        convertedBalanceStore: ConvertedBalanceStore,
        currencyStore: CurrencyStore
    ) {
        self.wallet = wallet
        self.sendAssetId = sendAssetId
        self.receiveAssetId = receiveAssetId
        self.assetDetailsService = assetDetailsService
        self.convertedBalanceStore = convertedBalanceStore
        self.currencyStore = currencyStore
    }

    func load() async throws -> MultichainSwapInitialAssets {
        let currency = currencyStore.state
        async let sendDetailsTask = assetDetailsService.loadAssetDetails(id: sendAssetId)
        async let receiveDetailsTask = assetDetailsService.loadAssetDetails(id: receiveAssetId)
        let sendDetails: TradingAssetDetails
        let receiveDetails: TradingAssetDetails
        do {
            (sendDetails, receiveDetails) = try await(sendDetailsTask, receiveDetailsTask)
        } catch {
            Log.multichainSwap.w(
                "legacy pair asset details loading failed",
                error: error,
                extraInfo: [
                    "sourceAsset": sendAssetId,
                    "destinationAsset": receiveAssetId,
                ]
            )
            throw error
        }
        let convertedBalance = convertedBalanceStore.getState()[wallet]?.balance
        let sendAsset = legacyAsset(details: sendDetails, convertedBalance: convertedBalance, currency: currency)
        let receiveAsset = legacyAsset(details: receiveDetails, convertedBalance: convertedBalance, currency: currency)
        Log.multichainSwap.i(
            "legacy pair assets loaded",
            extraInfo: [
                "sourceAsset": sendAsset.asset.assetId,
                "destinationAsset": receiveAsset.asset.assetId,
                "sourceBalance": sendAsset.balance.description,
            ]
        )
        return MultichainSwapInitialAssets(
            sendAsset: sendAsset,
            receiveAsset: receiveAsset,
            slippage: nil,
            usdFiatRate: nil
        )
    }
}

private extension LegacyPairMultichainSwapDefaultAssetsService {
    struct Holding {
        let amount: BigUInt
        let price: Decimal
    }

    func legacyAsset(
        details: TradingAssetDetails,
        convertedBalance: ConvertedBalance?,
        currency: Currency
    ) -> MultichainAsset {
        let holding = convertedBalance.flatMap { self.holding(assetId: details.assetInfo.assetId, convertedBalance: $0) }
        var prices = [String: Double]()
        if let holding, holding.price > 0 {
            prices[currency.code.lowercased()] = NSDecimalNumber(decimal: holding.price).doubleValue
        }
        return MultichainAsset(
            asset: MultichainAssetDetails(assetInfo: details.assetInfo),
            price: MultichainAssetPrice(
                prices: prices,
                diff24h: [:],
                diff7d: [:]
            ),
            balance: holding?.amount ?? 0
        )
    }

    func holding(assetId: String, convertedBalance: ConvertedBalance) -> Holding? {
        switch TradingAssetToken(assetId: assetId) {
        case .ton:
            let item = convertedBalance.tonBalance
            return Holding(amount: BigUInt(max(item.tonBalance.amount, 0)), price: item.price)
        case .tronUsdt:
            return convertedBalance.tronUSDT.map { Holding(amount: $0.amount, price: $0.price) }
        case .tronTrx:
            return convertedBalance.tronTRX.map { Holding(amount: $0.amount, price: $0.price) }
        case .jetton, .none:
            return nil
        }
    }
}

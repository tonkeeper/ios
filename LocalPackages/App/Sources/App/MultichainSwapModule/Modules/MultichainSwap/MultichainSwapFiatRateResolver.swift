import Foundation
import KeeperCore

/// Backend price dictionaries are not consistent about currency-code casing, so
/// every lookup goes through this case-insensitive helper.
func multichainAssetPrice(for currencyCode: String, in prices: [String: Double]) -> Double? {
    for key in [currencyCode, currencyCode.uppercased(), currencyCode.lowercased()] {
        if let value = prices[key] {
            return value
        }
    }
    return prices.first { $0.key.caseInsensitiveCompare(currencyCode) == .orderedSame }?.value
}

/// Single owner of fiat-rate resolution for the swap screen: derives the USD →
/// display-currency FX rate and picks the price an asset is displayed or
/// entered with. Conversions and formatting stay in
/// `MultichainSwapAmountCalculator`.
struct MultichainSwapFiatRateResolver {
    let displayCurrency: Currency

    /// The wallet-derived FX rate when available, else the rate recovered from the
    /// quote itself (display price of the send asset over its route USD price).
    func effectiveUsdFiatRate(
        inputs: MultichainSwapInputs,
        quote: MultichainSwapQuoteSnapshot
    ) -> Decimal? {
        inputs.usdFiatRate ?? quoteDerivedUsdFiatRate(
            sendAsset: inputs.sendAsset,
            routeSourceUsdPrice: quote.sourceUsdPrice
        )
    }

    /// Wallet asset prices are requested in both the display currency and USD
    /// (`requestedCurrencyCodes`), so their ratio yields the USD → display-currency
    /// conversion for the USD-only catalog and route prices.
    func walletDerivedUsdFiatRate(walletAssets: [MultichainAsset]) -> Decimal? {
        guard displayCurrency != .USD else {
            return 1
        }
        for asset in walletAssets {
            guard let displayPrice = multichainAssetPrice(
                for: displayCurrency.code,
                in: asset.price.prices
            ), displayPrice > 0,
            let usdPrice = multichainAssetPrice(
                for: Currency.USD.code,
                in: asset.price.prices
            ), usdPrice > 0
            else {
                continue
            }
            return Decimal(displayPrice) / Decimal(usdPrice)
        }
        return nil
    }

    /// FX rate recovered from a ready quote when the wallet-derived one is missing:
    /// the send asset is always priced in the display currency (it sits on the
    /// balance), and the route quotes the same asset in USD.
    func quoteDerivedUsdFiatRate(
        sendAsset: MultichainAsset,
        routeSourceUsdPrice: Double?
    ) -> Decimal? {
        guard displayCurrency != .USD else {
            return 1
        }
        guard let routeSourceUsdPrice, routeSourceUsdPrice > 0,
              let displayPrice = lookupPrice(in: sendAsset.price.prices),
              displayPrice > 0
        else {
            return nil
        }
        return Decimal(displayPrice) / Decimal(routeSourceUsdPrice)
    }

    /// Resolves the display-currency price of an asset: its own display-currency
    /// price when known, else a USD price (catalog assets and quote routes carry
    /// USD exclusively) converted through the FX rate.
    func fiatRate(
        for asset: MultichainAsset,
        usdFiatRate: Decimal?,
        fallbackUsdPrice: Double? = nil
    ) -> Decimal? {
        if let price = lookupPrice(in: asset.price.prices), price > 0 {
            return Decimal(price)
        }
        guard let usdToDisplayCurrencyRate = usdToDisplayCurrencyRate(usdFiatRate) else {
            return nil
        }
        if let usdPrice = multichainAssetPrice(for: Currency.USD.code, in: asset.price.prices),
           usdPrice > 0
        {
            return Decimal(usdPrice) * usdToDisplayCurrencyRate
        }
        if let fallbackUsdPrice, fallbackUsdPrice > 0 {
            return Decimal(fallbackUsdPrice) * usdToDisplayCurrencyRate
        }
        return nil
    }

    func hasFiatPrice(
        for asset: MultichainAsset,
        usdFiatRate: Decimal?,
        fallbackUsdPrice: Double? = nil
    ) -> Bool {
        fiatRate(for: asset, usdFiatRate: usdFiatRate, fallbackUsdPrice: fallbackUsdPrice) != nil
    }

    /// Whether the asset may render fiat at all: a known display-currency price,
    /// a USD price, or a route fallback price convertible through the FX rate.
    func canRenderFiat(
        for asset: MultichainAsset,
        usdFiatRate: Decimal?,
        fallbackUsdPrice: Double? = nil
    ) -> Bool {
        hasFiatPrice(for: asset, usdFiatRate: usdFiatRate, fallbackUsdPrice: fallbackUsdPrice)
    }

    /// Symbol rendered as the fixed prefix of an amount field in fiat mode.
    func fiatInputSymbol(
        for asset: MultichainAsset,
        usdFiatRate: Decimal?,
        fallbackUsdPrice: Double? = nil
    ) -> String? {
        guard canRenderFiat(for: asset, usdFiatRate: usdFiatRate, fallbackUsdPrice: fallbackUsdPrice) else {
            return nil
        }
        return displayCurrency.symbol
    }

    func lookupPrice(in prices: [String: Double]) -> Double? {
        multichainAssetPrice(for: displayCurrency.code, in: prices)
    }

    private func usdToDisplayCurrencyRate(_ usdFiatRate: Decimal?) -> Decimal? {
        displayCurrency == .USD ? 1 : usdFiatRate
    }
}

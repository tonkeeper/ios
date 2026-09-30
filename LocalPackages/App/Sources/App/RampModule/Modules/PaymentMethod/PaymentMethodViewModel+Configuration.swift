import Foundation
import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import UIKit

extension PaymentMethodViewModelImplementation {
    var placeholderOverlayKind: PaymentMethodPlaceholderOverlayKind? {
        if state == .loading { return nil }
        if state == .failed { return .loadError }
        if hasContent { return nil }
        switch rampLayoutItem.type {
        case .fiat:
            guard onRampLayout != nil else { return nil }
            return .emptyNoCashForCurrency
        case .crypto, .stablecoin:
            return .empty
        }
    }

    func buildSnapshot() {
        var snapshot = PaymentMethodViewController.Snapshot()

        if state == .loading {
            snapshot.appendSections([.shimmer(0)])
            snapshot.appendItems([.shimmer(sectionIndex: 0)], toSection: .shimmer(0))
            didUpdateSnapshot?(snapshot)
            return
        }

        switch rampLayoutItem.type {
        case .fiat:
            let cashSection = PaymentMethodViewController.Section.cashMethods(title: nil)
            snapshot.appendSections([cashSection])
            if onRampLayout != nil, !asset.cashMethods.isEmpty {
                snapshot.appendItems(asset.cashMethods.map { .cashMethod($0) }, toSection: cashSection)
            }

        case .crypto:
            if state != .failed {
                let cryptoMethods = asset.cryptoMethods
                if !cryptoMethods.isEmpty {
                    if asset.symbol.uppercased() == TonInfo.symbol, flow == .deposit {
                        let text = TKLocales.Ramp.Deposit.PaymentMethod.cryptoSwapToTonBanner
                        let warningSection = PaymentMethodViewController.Section.warning(text: text)
                        snapshot.appendSections([warningSection])
                        snapshot.appendItems([.warningBanner], toSection: warningSection)
                    }
                    let cryptoSection = PaymentMethodViewController.Section.cryptoMethods
                    snapshot.appendSections([cryptoSection])
                    let maxVisible = 10
                    let showAllMethodsRow = cryptoMethods.count > maxVisible
                    let visibleCount = showAllMethodsRow ? maxVisible - 1 : cryptoMethods.count
                    let visibleAssets = Array(cryptoMethods.prefix(visibleCount))
                    let cryptoItems: [PaymentMethodViewController.Item] = visibleAssets.map { .cryptoMethod($0) }
                    snapshot.appendItems(cryptoItems, toSection: cryptoSection)
                    if showAllMethodsRow {
                        let first = cryptoMethods[maxVisible - 1]
                        let second = cryptoMethods[maxVisible]
                        snapshot.appendItems([.allCryptoMethods(first: first, second: second)], toSection: cryptoSection)
                    }
                }
            }

        case .stablecoin:
            if state != .failed {
                let items = stablecoinItems(for: asset)
                if !items.isEmpty {
                    let warningSection = PaymentMethodViewController.Section.warning(text: stablecoinPaymentWarningBannerText)
                    let stablecoinsSection = PaymentMethodViewController.Section.stablecoins
                    snapshot.appendSections([warningSection, stablecoinsSection])
                    snapshot.appendItems([.warningBanner], toSection: warningSection)
                    snapshot.appendItems(items, toSection: stablecoinsSection)
                }
            }
        }

        didUpdateSnapshot?(snapshot)
    }

    func stablecoinItems(for asset: RampAsset) -> [PaymentMethodViewController.Item] {
        var networksBySymbol: [String: [OnRampLayoutCryptoMethod]] = [:]

        for cryptoMethod in asset.cryptoMethods {
            guard cryptoMethod.stablecoin else { continue }
            if asset.network == cryptoMethod.network, asset.symbol == cryptoMethod.symbol { continue }

            if let existingNetworks = networksBySymbol[cryptoMethod.symbol] {
                networksBySymbol[cryptoMethod.symbol] = existingNetworks + [cryptoMethod]
            } else {
                networksBySymbol[cryptoMethod.symbol] = [cryptoMethod]
            }
        }

        let preferredStablecoinSymbols = ["USDC", "USDT", "DAI"]
        var orderedSymbols: [String] = []
        var usedKeys = Set<String>()
        for preferred in preferredStablecoinSymbols {
            if let key = networksBySymbol.keys.first(where: { $0.uppercased() == preferred }) {
                orderedSymbols.append(key)
                usedKeys.insert(key)
            }
        }
        for key in networksBySymbol.keys.sorted() where !usedKeys.contains(key) {
            orderedSymbols.append(key)
        }

        return orderedSymbols.map { symbol in
            .stablecoin(
                symbol: symbol,
                image: networksBySymbol[symbol]?.first?.image,
                networkMethods: networksBySymbol[symbol] ?? []
            )
        }
    }

    var title: String {
        switch (rampLayoutItem.type, flow) {
        case (.fiat, .withdraw):
            return TKLocales.Ramp.Withdraw.PaymentMethod.receiveMethodTitle
        case (.stablecoin, .withdraw):
            return TKLocales.Ramp.Withdraw.PaymentMethod.assetToReceiveTitle
        default:
            return TKLocales.Ramp.Deposit.PaymentMethod.title
        }
    }

    var stablecoinPaymentWarningBannerText: String {
        switch flow {
        case .deposit:
            return asset.isTronNetwork
                ? TKLocales.Ramp.Deposit.PaymentMethod.stablecoinCreditUsdtTronBanner
                : TKLocales.Ramp.Deposit.PaymentMethod.stablecoinCreditUsdtTonBanner
        case .withdraw: return TKLocales.Ramp.Withdraw.PaymentMethod.stablecoinWithdrawNetworkFeeBanner
        }
    }

    var hasContent: Bool {
        switch rampLayoutItem.type {
        case .fiat:
            return onRampLayout != nil && !asset.cashMethods.isEmpty
        case .crypto:
            return !asset.cryptoMethods.isEmpty
        case .stablecoin:
            return !stablecoinItems(for: asset).isEmpty
        }
    }
}

import Foundation
import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import UIKit

extension PaymentMethodViewModelImplementation {
    func buildSnapshot() {
        var snapshot = PaymentMethodViewController.Snapshot()

        if isLoading {
            snapshot.appendSections([.shimmer(0), .shimmer(1)])
            snapshot.appendItems([.shimmer(sectionIndex: 0)], toSection: .shimmer(0))
            snapshot.appendItems([.shimmer(sectionIndex: 1)], toSection: .shimmer(1))
            didUpdateSnapshot?(snapshot)
            return
        }

        let cashMethods = asset.cashMethods
        let cryptoMethods = asset.cryptoMethods

        snapshot.appendSections([.cashMethods(cashSectionTitle)])

        if !cashMethods.isEmpty {
            if !asset.stablecoin, flow == .withdraw {
                snapshot.appendItems(cashMethods.map { .cashMethod($0) }, toSection: .cashMethods(cashSectionTitle))
            } else {
                let maxVisible = 4
                let showAllMethodsRow = cashMethods.count > maxVisible
                let visibleCount = showAllMethodsRow ? maxVisible - 1 : cashMethods.count
                let cashItems: [PaymentMethodViewController.Item] = cashMethods.prefix(visibleCount).map { .cashMethod($0) }
                var itemsToAppend = cashItems
                if showAllMethodsRow {
                    itemsToAppend.append(.allMethods(first: cashMethods[3], second: cashMethods[4]))
                }
                snapshot.appendItems(itemsToAppend, toSection: .cashMethods(cashSectionTitle))
            }
        }

        if asset.stablecoin {
            let items = stablecoinItems(for: asset)
            if !items.isEmpty {
                let stablecoinsSection: PaymentMethodViewController.Section = .convertFromStablecoins(
                    title: stablecoinsSectionTitle,
                    subtitle: stablecoinsSectionSubtitle
                )
                snapshot.appendSections([stablecoinsSection])
                snapshot.appendItems(items, toSection: stablecoinsSection)
            }
        } else {
            if !cryptoMethods.isEmpty {
                let cryptoSection = PaymentMethodViewController.Section.convertFromCrypto(title: cryptoSectionTitle)
                snapshot.appendSections([cryptoSection])
                let maxVisible = 4
                let showAllAssetsRow = cryptoMethods.count > maxVisible
                let visibleCount = showAllAssetsRow ? maxVisible - 1 : cryptoMethods.count
                let visibleAssets = Array(cryptoMethods.prefix(visibleCount))
                let cryptoItems: [PaymentMethodViewController.Item] = visibleAssets.map { .cryptoAsset($0) }
                snapshot.appendItems(cryptoItems, toSection: cryptoSection)
                if showAllAssetsRow {
                    let first = cryptoMethods[3]
                    let second = cryptoMethods[4]
                    snapshot.appendItems([.allAssets(first: first, second: second)], toSection: cryptoSection)
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
        switch flow {
        case .deposit: return TKLocales.Ramp.Deposit.PaymentMethod.title
        case .withdraw: return TKLocales.Ramp.Withdraw.PaymentMethod.title
        }
    }

    var cashSectionTitle: String {
        switch flow {
        case .deposit: return TKLocales.Ramp.Deposit.PaymentMethod.buyWithCash
        case .withdraw: return TKLocales.Ramp.Withdraw.PaymentMethod.sellToCash
        }
    }

    var cryptoSectionTitle: String {
        switch flow {
        case .deposit: return TKLocales.Ramp.Deposit.PaymentMethod.convertFromCrypto
        case .withdraw: return TKLocales.Ramp.Withdraw.PaymentMethod.sellWithCrypto
        }
    }

    var stablecoinsSectionTitle: String {
        switch flow {
        case .deposit: return TKLocales.Ramp.Deposit.PaymentMethod.convertFromStablecoins
        case .withdraw: return TKLocales.Ramp.Withdraw.PaymentMethod.sellToStablecoins
        }
    }

    var stablecoinsSectionSubtitle: String? {
        switch flow {
        case .deposit: return TKLocales.Ramp.Deposit.PaymentMethod.convertFromStablecoinsDescription(symbol: asset.symbol, networkName: asset.networkName)
        case .withdraw: return TKLocales.Ramp.Withdraw.PaymentMethod.sellToStablecoinsDescription
        }
    }
}

//
//  IntentHandler.swift
//  TonkeeperIntents
//
//  Created by Grigory on 3.10.23..
//

import Intents
import KeeperCore
import TKCore
import TKUIKit
import UIKit
import WalletExtensions

class IntentHandler: INExtension, RateWidgetIntentHandling, BalanceWidgetIntentHandling {
    func provideWalletOptionsCollection(for intent: BalanceWidgetIntent) async throws -> INObjectCollection<WidgetWallet> {
        let coreAssembly = TKCore.CoreAssembly()
        let keeperCoreAssembly = KeeperCore.Assembly(
            dependencies: Assembly.Dependencies(
                cacheURL: coreAssembly.cacheURL,
                sharedCacheURL: coreAssembly.sharedCacheURL,
                appInfoProvider: coreAssembly.appInfoProvider,
                featureFlags: coreAssembly.featureFlags,
                seedProvider: { "" }
            )
        )

        let widgetAssembly = keeperCoreAssembly.widgetAssembly()
        let walletsService = widgetAssembly.walletsService
        let wallets = try walletsService.getWallets()
        let widgetWallets = wallets.compactMap { wallet in
            let display: String
            var image: INImage?
            switch wallet.icon {
            case let .emoji(emoji):
                display = "\(emoji)    \(wallet.label)"
                image = nil
            case let .icon(icon):
                if let data = icon.image?.pngData() {
                    image = INImage(imageData: data)
                }
                display = wallet.label
            }
            let item = try? WidgetWallet(identifier: wallet.identity.identifier().string, display: display)
            item?.displayImage = image
            return item
        }
        return INObjectCollection(items: widgetWallets)
    }

    func provideCurrencyOptionsCollection(
        for intent: BalanceWidgetIntent,
        with completion: @escaping (INObjectCollection<WidgetCurrency>?, Error?) -> Void
    ) {
        let currencies: [WidgetCurrency] = KeeperCore.Currency.allCases.map { currency in
            WidgetCurrency(identifier: currency.code, display: currency.code)
        }

        let collection = INObjectCollection(items: currencies)
        completion(collection, nil)
    }

    func provideCurrencyOptionsCollection(
        for intent: RateWidgetIntent,
        with completion: @escaping (INObjectCollection<WidgetCurrency>?, Error?) -> Void
    ) {
        let currencies: [WidgetCurrency] = KeeperCore.Currency.allCases.map { currency in
            WidgetCurrency(identifier: currency.code, display: currency.code)
        }

        let collection = INObjectCollection(items: currencies)
        completion(collection, nil)
    }
}

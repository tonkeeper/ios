import Foundation
import TKLogging

/// Represents the entire state of the application install
public struct KeeperInfo: Equatable {
    /// Keeper contains multiple wallets
    public let wallets: [Wallet]

    /// Currently selected wallet
    public let currentWallet: Wallet

    /// Currently selected currency
    public let currency: Currency

    /// Common pin/faceid settings
    public let securitySettings: SecuritySettings

    public let appSettings: AppSettings

    public let country: SelectedCountry

    public let batterySettings: BatterySettings

    ///
    let assetsPolicy: AssetsPolicy
    let appCollection: AppCollection

    public init(
        wallets: [Wallet],
        currentWallet: Wallet,
        currency: Currency,
        securitySettings: SecuritySettings,
        appSettings: AppSettings,
        country: SelectedCountry,
        batterySettings: BatterySettings = BatterySettings()
    ) {
        self.init(
            wallets: wallets,
            currentWallet: currentWallet,
            currency: currency,
            securitySettings: securitySettings,
            appSettings: appSettings,
            country: country,
            batterySettings: batterySettings,
            assetsPolicy: AssetsPolicy(policies: [:], ordered: []),
            appCollection: AppCollection(connected: [:], recent: [], pinned: [])
        )
    }

    init(
        wallets: [Wallet],
        currentWallet: Wallet,
        currency: Currency,
        securitySettings: SecuritySettings,
        appSettings: AppSettings,
        country: SelectedCountry,
        batterySettings: BatterySettings,
        assetsPolicy: AssetsPolicy,
        appCollection: AppCollection
    ) {
        self.wallets = wallets
        self.currentWallet = currentWallet
        self.currency = currency
        self.securitySettings = securitySettings
        self.appSettings = appSettings
        self.country = country
        self.batterySettings = batterySettings
        self.assetsPolicy = assetsPolicy
        self.appCollection = appCollection
    }
}

extension KeeperInfo: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.wallets = try container.decode(DecodableWalletList.self, forKey: .wallets).wallets
        guard let firstWallet = wallets.first else {
            throw DecodingError.dataCorruptedError(
                forKey: .wallets,
                in: container,
                debugDescription: "no stored wallet could be decoded"
            )
        }

        do {
            self.currentWallet = try container.decode(Wallet.self, forKey: .currentWallet)
        } catch {
            Log.e("🪵 KeeperInfo: current wallet is undecodable, falling back to the first wallet", error: error)
            self.currentWallet = firstWallet
        }
        self.currency = try container.decode(Currency.self, forKey: .currency)
        self.securitySettings = try container.decode(SecuritySettings.self, forKey: .securitySettings)

        if let appSettings = try container.decodeIfPresent(AppSettings.self, forKey: .appSettings) {
            self.appSettings = appSettings
        } else {
            self.appSettings = AppSettings(isSecureMode: false, searchEngine: .duckduckgo)
        }

        self.assetsPolicy = try container.decode(AssetsPolicy.self, forKey: .assetsPolicy)
        self.appCollection = try container.decode(AppCollection.self, forKey: .appCollection)
        if let selectedCountry = try container.decodeIfPresent(SelectedCountry.self, forKey: .country) {
            self.country = selectedCountry
        } else {
            self.country = .auto
        }

        if let batterySettings = try container.decodeIfPresent(BatterySettings.self, forKey: .batterySettings) {
            self.batterySettings = batterySettings
        } else {
            self.batterySettings = BatterySettings()
        }
    }
}

private struct DecodableWalletList: Decodable {
    let wallets: [Wallet]

    init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var wallets: [Wallet] = []
        while !container.isAtEnd {
            let index = container.currentIndex
            do {
                try wallets.append(container.decode(Wallet.self))
            } catch {
                // A failed decode leaves the container on the same element; consuming it moves past it.
                _ = try container.decode(SkippedElement.self)
                Log.e("🪵 KeeperInfo: skipped undecodable wallet at index \(index)", error: error)
            }
        }
        self.wallets = wallets
    }
}

private struct SkippedElement: Decodable {
    init(from decoder: any Decoder) throws {}
}

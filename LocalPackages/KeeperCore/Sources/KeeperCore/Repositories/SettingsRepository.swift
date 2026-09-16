import Foundation
import KeeperCoreComponents

public struct SettingsRepository {
    private let settingsVault: SettingsVault<SettingsKey>

    init(settingsVault: SettingsVault<SettingsKey>) {
        self.settingsVault = settingsVault
    }

    public var isFirstRun: Bool {
        get {
            settingsVault.value(key: .isFirstRun) ?? true
        }
        set {
            settingsVault.setValue(newValue, key: .isFirstRun)
        }
    }

    public var seed: String {
        get {
            settingsVault.value(key: .seed) ?? ""
        }
        set {
            settingsVault.setValue(newValue, key: .seed)
        }
    }

    public var didOpenWalletMigration: Bool {
        get {
            settingsVault.value(key: .didOpenWalletMigration) ?? false
        }
        set {
            settingsVault.setValue(newValue, key: .didOpenWalletMigration)
        }
    }

    public var didMigrateLegacyTronWalletsV1: Bool {
        get {
            settingsVault.value(key: .didMigrateLegacyTronWalletsV1) ?? false
        }
        set {
            settingsVault.setValue(newValue, key: .didMigrateLegacyTronWalletsV1)
        }
    }

    struct TransactionSettings: Codable {
        enum FeeOption: Codable {
            case `default`
            case gasless
            case battery
        }

        var jettonTransfer: FeeOption = .battery
        var nftTransfer: FeeOption = .battery
        var swap: FeeOption = .battery
    }

    func getTransferSettings(wallet: Wallet) -> TransactionSettings {
        guard let data: Data = settingsVault.value(key: .transferSettings),
              let settings = try? JSONDecoder().decode([Wallet: TransactionSettings].self, from: data),
              let walletSettings = settings[wallet] else { return TransactionSettings() }
        return walletSettings
    }

    func setTransferSettings(
        wallet: Wallet,
        transferSettings: TransactionSettings
    ) throws {
        var settings: [Wallet: TransactionSettings] = try {
            if let data: Data = settingsVault.value(key: .transferSettings) {
                let decoder = JSONDecoder()
                return try decoder.decode([Wallet: TransactionSettings].self, from: data)
            } else {
                return [:]
            }
        }()

        settings[wallet] = transferSettings
        let data = try JSONEncoder().encode(settings)
        settingsVault.setValue(data, key: .transferSettings)
    }
}

enum SettingsKey: String, CustomStringConvertible {
    var description: String {
        rawValue
    }

    case seed
    case isFirstRun
    case didMigrateV2
    case didMigrateV3
    case didMigrateRN
    case didOpenWalletMigration
    case didMigrateLegacyTronWalletsV1
    case transferSettings
}

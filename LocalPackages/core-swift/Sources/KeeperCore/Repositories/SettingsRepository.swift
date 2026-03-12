import CoreComponents
import Foundation

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

    public var didMigrateV2: Bool {
        get {
            settingsVault.value(key: .didMigrateV2) ?? false
        }
        set {
            settingsVault.setValue(newValue, key: .didMigrateV2)
        }
    }

    public var didMigrateV3: Bool {
        get {
            settingsVault.value(key: .didMigrateV3) ?? false
        }
        set {
            settingsVault.setValue(newValue, key: .didMigrateV3)
        }
    }

    public var didMigrateRN: Bool {
        get {
            settingsVault.value(key: .didMigrateRN) ?? false
        }
        set {
            settingsVault.setValue(newValue, key: .didMigrateRN)
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

public enum SettingsKey: String, CustomStringConvertible {
    public var description: String {
        rawValue
    }

    case seed
    case isFirstRun
    case didMigrateV2
    case didMigrateV3
    case didMigrateRN
    case transferSettings
}

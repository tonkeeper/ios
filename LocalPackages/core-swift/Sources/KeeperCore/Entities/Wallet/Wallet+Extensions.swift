import Foundation
import TonSwift

public extension Wallet {
    enum Error: Swift.Error {
        case invalidWalletKind
    }

    enum Kind {
        case regular
        case lockup
        case watchonly
        case signer
        case ledger
        case keystone
    }

    var kind: Kind {
        switch identity.kind {
        case .Regular:
            return .regular
        case .Lockup:
            return .lockup
        case .Watchonly:
            return .watchonly
        case .Signer:
            return .signer
        case .SignerDevice:
            return .signer
        case .Ledger:
            return .ledger
        case .Keystone:
            return .keystone
        }
    }

    var isLedger: Bool {
        return kind == .ledger
    }

    var network: Network {
        identity.network
    }

    var publicKey: TonSwift.PublicKey {
        get throws {
            switch identity.kind {
            case let .Regular(publicKey, _):
                return publicKey
            case let .Lockup(publicKey, _):
                return publicKey
            case .Watchonly:
                throw Error.invalidWalletKind
            case let .Signer(publicKey, _):
                return publicKey
            case let .SignerDevice(publicKey, _):
                return publicKey
            case let .Ledger(publicKey, _, _):
                return publicKey
            case let .Keystone(publicKey, _, _, _):
                return publicKey
            }
        }
    }

    var contractVersion: WalletContractVersion {
        get throws {
            switch identity.kind {
            case let .Regular(_, contractVersion):
                return contractVersion
            case .Lockup:
                throw Error.invalidWalletKind
            case .Watchonly:
                throw Error.invalidWalletKind
            case let .Signer(_, contractVersion):
                return contractVersion
            case let .SignerDevice(_, contractVersion):
                return contractVersion
            case let .Ledger(_, contractVersion, _):
                return contractVersion
            case let .Keystone(_, _, _, contractVersion):
                return contractVersion
            }
        }
    }

    var contract: WalletContract {
        get throws {
            let publicKey = try publicKey
            let contractVersion = try contractVersion

            let networkRawValue = network.walletNetworkGlobalId

            switch contractVersion {
            case .v3R1:
                return try WalletV3(workchain: 0, publicKey: publicKey.data, revision: .r1)
            case .v3R2:
                return try WalletV3(workchain: 0, publicKey: publicKey.data, revision: .r2)
            case .v4R1:
                return WalletV4R1(publicKey: publicKey.data)
            case .v4R2:
                return WalletV4R2(publicKey: publicKey.data)
            case .v5Beta:
                return WalletV5Beta(
                    publicKey: publicKey.data,
                    walletId: WalletIdBeta(
                        networkGlobalId: Int32(
                            networkRawValue
                        ),
                        workchain: 0
                    )
                )
            case .v5R1:
                return WalletV5R1(
                    publicKey: publicKey.data,
                    walletId: WalletId(
                        networkGlobalId: Int32(
                            networkRawValue
                        ),
                        workchain: 0
                    )
                )
            }
        }
    }

    var stateInit: StateInit {
        get throws {
            try contract.stateInit
        }
    }

    var address: Address {
        get throws {
            switch identity.kind {
            case .Regular:
                return try contract.address()
            case .Lockup:
                return try contract.address()
            case let .Watchonly(address):
                switch address {
                case let .Resolved(address):
                    return address
                case let .Domain(_, address):
                    return address
                }
            case .Signer, .SignerDevice:
                return try contract.address()
            case .Ledger:
                return try contract.address()
            case .Keystone:
                return try contract.address()
            }
        }
    }

    var friendlyAddress: FriendlyAddress {
        get throws {
            let isTestnet = self.network == .testnet
            let address = try self.address
            return address.toFriendly(testOnly: isTestnet, bounceable: false)
        }
    }

    var addressToCopy: String? {
        try? friendlyAddress.toString()
    }

    var isTonconnectAvailable: Bool {
        switch kind {
        case .regular:
            return true
        case .lockup:
            return false
        case .watchonly:
            return false
        case .signer:
            return false
        case .ledger:
            return true
        case .keystone:
            return true
        }
    }

    var isGaslessAvailable: Bool {
        isW5Generation
    }

    var isV4R2: Bool {
        do {
            return try contractVersion == .v4R2
        } catch {
            return false
        }
    }

    var isW5: Bool {
        do {
            return try contractVersion == .v5R1
        } catch {
            return false
        }
    }

    var isW5Beta: Bool {
        do {
            return try contractVersion == .v5Beta
        } catch {
            return false
        }
    }

    var isW5Generation: Bool {
        isW5 || isW5Beta
    }

    var isSendAvailable: Bool {
        switch kind {
        case .regular:
            return true
        case .lockup:
            return false
        case .watchonly:
            return false
        case .signer:
            return true
        case .ledger:
            return true
        case .keystone:
            return true
        }
    }

    var isBiometryAvailable: Bool {
        switch kind {
        case .regular:
            return true
        default:
            return false
        }
    }

    var isBackupAvailable: Bool {
        switch kind {
        case .regular:
            return true
        default:
            return false
        }
    }

    var hasBackup: Bool {
        setupSettings.backupDate != nil
    }

    var label: String {
        metaData.label
    }

    var icon: WalletIcon {
        metaData.icon
    }

    var tintColor: WalletTintColor {
        metaData.tintColor
    }

    var isSendEnable: Bool {
        switch kind {
        case .regular, .signer, .ledger, .keystone:
            return true
        case .watchonly, .lockup:
            return false
        }
    }

    var isReceiveEnable: Bool {
        switch kind {
        case .regular, .signer, .ledger, .watchonly, .keystone:
            return true
        case .lockup:
            return false
        }
    }

    var isScanEnable: Bool {
        switch kind {
        case .regular, .signer, .ledger, .keystone:
            return true
        case .watchonly, .lockup:
            return false
        }
    }

    var isSwapEnable: Bool {
        switch kind {
        case .regular, .signer, .ledger, .keystone:
            return true
        case .watchonly, .lockup:
            return false
        }
    }

    var isBuyEnable: Bool {
        switch kind {
        case .regular, .signer, .ledger, .watchonly, .keystone:
            return true
        case .lockup:
            return false
        }
    }

    var isStakeEnable: Bool {
        switch kind {
        case .regular, .signer, .ledger, .keystone:
            return true
        case .watchonly, .lockup:
            return false
        }
    }

    var isBatteryEnable: Bool {
        switch kind {
        case .regular:
            return true
        default:
            return false
        }
    }

    var isReportSpamAvailable: Bool {
        kind != .watchonly && network == .mainnet
    }
}

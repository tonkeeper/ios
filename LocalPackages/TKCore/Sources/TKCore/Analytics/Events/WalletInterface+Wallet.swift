import KeeperCore
import TKLogging

private let errorTag = "Analytics Failure (WalletInterface)"

extension Wallet {
    func transactionInterface(
        for asset: String
    ) -> WalletInterface? {
        guard let asset = AssetIdComponents(assetId: asset) else {
            Log.e(errorTag, extraInfo: [
                "reason": "bad format: \(asset)",
            ])
            return nil
        }
        guard let chain = MultichainChain(assetIdChain: asset.chain) else {
            Log.e(errorTag, extraInfo: [
                "reason": "bad chain: \(asset.chain)",
            ])
            return nil
        }

        switch chain {
        case .ton:
            switch tonInterface {
            case .readonly:
                Log.e(errorTag, extraInfo: [
                    "reason": "readonly wallet kind for transaction event",
                ])
                return nil
            case let .regular(contract):
                return contract.asWalletInterface
            }
        case .eth, .base, .arb, .bsc, .tron:
            return .eoa
        case .btc:
            return btcInterface
        }
    }
}

// MARK: -

enum TonWalletInterface {
    case readonly
    case regular(WalletContractVersion)
}

extension WalletContractVersion {
    var asWalletInterface: WalletInterface {
        switch self {
        case .v3R1:
            return .v3r1
        case .v3R2:
            return .v3r2
        case .v4R1:
            return .v4r1
        case .v4R2:
            return .v4r2
        case .v5Beta:
            return .v5beta
        case .v5R1:
            return .v5r1
        }
    }
}

extension Wallet {
    var tonInterface: TonWalletInterface {
        switch identity.kind {
        case
            let .Regular(_, contractVersion),
            let .Signer(_, contractVersion),
            let .SignerDevice(_, contractVersion),
            let .Ledger(_, contractVersion, _),
            let .Keystone(_, _, _, contractVersion):
            .regular(contractVersion)
        case .Lockup, .Watchonly:
            .readonly
        }
    }
}

// MARK: -

extension Wallet {
    var btcInterface: WalletInterface? {
        guard case let .multichain(state) = multichain else {
            Log.e(errorTag, extraInfo: [
                "reason": "wallet is not a multichain",
            ])
            return nil
        }
        let address = state.addresses
            .first {
                $0.chain == .btc
            }

        guard let address else {
            Log.e(errorTag, extraInfo: [
                "reason": "wallet does not contain btc address",
            ])
            return nil
        }

        return address.address.btcInterface
    }
}

private extension String {
    var btcInterface: WalletInterface {
        let normalizedAddress = self
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if ["bc1p", "tb1p", "bcrt1p"].contains(where: normalizedAddress.hasPrefix) {
            return .taproot
        }

        if ["bc1q", "tb1q", "bcrt1q"].contains(where: normalizedAddress.hasPrefix) {
            return .segwit
        }

        if ["3", "2"].contains(where: normalizedAddress.hasPrefix) {
            return .p2sh
        }

        return .legacy
    }
}

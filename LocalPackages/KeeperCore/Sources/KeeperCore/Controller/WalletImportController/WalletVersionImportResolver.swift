import Foundation
import KeeperCoreSensitive

public enum WalletVersionImportResolver {
    public enum Resolution {
        case importRevision(WalletContractVersion)
        case showVersionSelection(v4r2: ActiveWalletModel, w5: ActiveWalletModel)
        case useExistingWalletSelection([ActiveWalletModel])
    }

    public static func resolve(
        mnemonic: CoreMnemonic,
        activeWallets: [ActiveWalletModel]
    ) -> Resolution {
        switch mnemonic.type {
        case .bip39, .bip39soft:
            return resolveBip39Wallets(activeWallets: activeWallets)
        case .ton, .unknown:
            return .useExistingWalletSelection(activeWallets)
        }
    }

    private static func resolveBip39Wallets(activeWallets: [ActiveWalletModel]) -> Resolution {
        guard let v4r2 = activeWallets.first(where: { $0.revision == .v4R2 }),
              let w5 = activeWallets.first(where: { $0.revision == .v5R1 })
        else {
            return .importRevision(.currentVersion)
        }

        let v4r2Funded = hasAssets(v4r2)
        let w5Funded = hasAssets(w5)

        if v4r2Funded, w5Funded {
            return .showVersionSelection(v4r2: v4r2, w5: w5)
        }

        if v4r2Funded {
            return .importRevision(.v4R2)
        }

        return .importRevision(.currentVersion)
    }

    private static func hasAssets(_ wallet: ActiveWalletModel) -> Bool {
        !wallet.balance.isEmpty || !wallet.nfts.isEmpty
    }
}

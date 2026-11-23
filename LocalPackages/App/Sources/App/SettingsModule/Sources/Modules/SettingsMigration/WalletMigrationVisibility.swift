import KeeperCore

enum WalletMigrationVisibility {
    static func shouldShowMigrationSection(
        wallet: Wallet,
        wallets: [Wallet]
    ) -> Bool {
        guard wallet.hasMultichainMnemonic else {
            return false
        }
        return legacyTonWalletCount(wallets: wallets) > 0
    }

    static func legacyTonWalletCount(wallets: [Wallet]) -> Int {
        wallets.filter { isLegacyTonWallet($0) }.count
    }

    static func hasMigratableLegacyWallets(
        wallets: [Wallet],
        walletMigrationService: WalletMigrationService,
        currency: Currency
    ) async -> Bool {
        let candidateWallets = wallets.filter { isLegacyTonWallet($0) }
        guard !candidateWallets.isEmpty else {
            return false
        }

        do {
            let migrationValues = try await walletMigrationService.getMigrationWallets(
                wallets: candidateWallets,
                currency: currency
            )
            return migrationValues.contains { $0.hasMigratableAssets }
        } catch {
            return false
        }
    }

    static func isLegacyTonWallet(_ wallet: Wallet) -> Bool {
        // Migrating a Telegram wallet's assets into a multichain wallet is not supported.
        guard case .regular = wallet.kind, case .mainnet = wallet.network, !wallet.isWalletTg else {
            return false
        }
        switch wallet.multichain {
        case .unavailable, .none:
            return true
        case .multichain:
            return false
        }
    }
}

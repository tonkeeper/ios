import Foundation
import TKLogging

public final class WalletDeleteController {
    private let walletStore: WalletsStore
    private let keeperInfoStore: KeeperInfoStore
    private let mnemonicAccess: MnemonicAccess
    private let securityStore: SecurityStore
    private let lighterCredentialsCleanup: (Wallet) -> Void
    private let multichainBindingCleanup: ([Wallet]) -> Void
    private let walletAuthTokenProvider: WalletAuthTokenProviding

    init(
        walletStore: WalletsStore,
        keeperInfoStore: KeeperInfoStore,
        mnemonicAccess: MnemonicAccess,
        securityStore: SecurityStore,
        walletAuthTokenProvider: WalletAuthTokenProviding,
        lighterCredentialsCleanup: @escaping (Wallet) -> Void = { _ in },
        multichainBindingCleanup: @escaping ([Wallet]) -> Void = { _ in }
    ) {
        self.walletStore = walletStore
        self.keeperInfoStore = keeperInfoStore
        self.mnemonicAccess = mnemonicAccess
        self.securityStore = securityStore
        self.walletAuthTokenProvider = walletAuthTokenProvider
        self.lighterCredentialsCleanup = lighterCredentialsCleanup
        self.multichainBindingCleanup = multichainBindingCleanup
    }

    public func deleteWallet(wallet: Wallet, passcode: String) async {
        let state = await walletStore.deleteWallet(wallet)
        do {
            try await mnemonicAccess.deleteMnemonic(wallet: wallet, passcode: passcode)
        } catch {
            #if DEBUG
                Log.e("🪵 mnemonic data is not deleted due to error: \(error)")
            #endif
        }
        lighterCredentialsCleanup(wallet)
        multichainBindingCleanup([wallet])
        await forgetWalletAuth(deleted: [wallet], remaining: state)
        await disableBiometryIfNeeded(walletsState: state)
    }

    public func deleteWallet(wallet: Wallet) async {
        let state = await walletStore.deleteWallet(wallet)
        lighterCredentialsCleanup(wallet)
        multichainBindingCleanup([wallet])
        await forgetWalletAuth(deleted: [wallet], remaining: state)
        await disableBiometryIfNeeded(walletsState: state)
    }

    public func deleteAll(passcode: String? = nil) async {
        let wallets = walletStore.wallets
        let state = await walletStore.deleteAllWallets()
        wallets.forEach(lighterCredentialsCleanup)
        multichainBindingCleanup(wallets)
        await walletAuthTokenProvider.wipe()
        do {
            try await mnemonicAccess.deleteAll(passcode: passcode)
        } catch {
            #if DEBUG
                Log.e("🪵 mnemonic data is not deleted due to error: \(error)")
            #endif
        }
        await disableBiometryIfNeeded(walletsState: state)
    }
}

private extension WalletDeleteController {
    /// Drops the wallet's app key and credential. Wallets differing only in TON contract version
    /// share a multichain walletId, so a key is only stale once no remaining wallet maps to it.
    func forgetWalletAuth(deleted: [Wallet], remaining: WalletsStore.State) async {
        let remainingWalletIds = Set(remaining.wallets.compactMap { $0.multichainWalletState?.walletId })
        let walletIds = Set(deleted.compactMap { $0.multichainWalletState?.walletId })
            .subtracting(remainingWalletIds)
        for walletId in walletIds {
            await walletAuthTokenProvider.forget(walletId: walletId)
        }
    }

    func disableBiometryIfNeeded(walletsState: WalletsStore.State) async {
        guard walletsState.wallets.isEmpty else {
            return
        }
        guard securityStore.getState().isBiometryEnable else {
            return
        }
        await securityStore.setIsBiometryEnable(false)
    }
}

import Foundation
import KeeperCoreComponents
import KeeperCoreSensitive
import TonSwift
import TonTransport

public final class WalletImportController {
    private let activeWalletService: ActiveWalletsService
    private let currencyService: CurrencyService

    init(
        activeWalletService: ActiveWalletsService,
        currencyService: CurrencyService
    ) {
        self.activeWalletService = activeWalletService
        self.currencyService = currencyService
    }

    public func findActiveWallets(
        mnemonic: CoreMnemonic,
        network: Network,
        checkHistory: Bool
    ) async throws -> [ActiveWalletModel] {
        let keyPair = try mnemonic.toKeyPair()
        let currency = (try? currencyService.getActiveCurrency()) ?? .USD
        return try await activeWalletService.loadActiveWallets(
            publicKey: keyPair.publicKey,
            network: network,
            currency: currency,
            checkHistory: checkHistory
        )
    }

    public func findActiveWallets(
        publicKey: TonSwift.PublicKey,
        network: Network,
        checkHistory: Bool
    ) async throws -> [ActiveWalletModel] {
        let currency = (try? currencyService.getActiveCurrency()) ?? .USD
        return try await activeWalletService.loadActiveWallets(
            publicKey: publicKey,
            network: network,
            currency: currency,
            checkHistory: checkHistory
        )
    }

    /// The found Telegram wallet with its jettons and NFTs. The lookup knows only its TON balance,
    /// so it stays as it is when they fail to load.
    public func loadTelegramWallet(
        _ telegramWallet: ActiveWalletModel,
        network: Network
    ) async -> ActiveWalletModel {
        let loaded = try? await findActiveWallets(
            accounts: [(id: telegramWallet.id, address: telegramWallet.address, revision: .walletTg)],
            network: network,
            checkHistory: false
        ).first
        guard let loaded, loaded.isActive else { return telegramWallet }
        return loaded
    }

    public func findActiveWallets(
        accounts: [(id: String, address: Address, revision: WalletContractVersion)],
        network: Network,
        checkHistory: Bool
    ) async throws -> [ActiveWalletModel] {
        let currency = (try? currencyService.getActiveCurrency()) ?? .USD
        return try await activeWalletService.loadActiveWallets(
            accounts: accounts,
            network: network,
            currency: currency,
            checkHistory: checkHistory
        )
    }
}

import CoreComponents
import Foundation
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

    public func findActiveWallets(phrase: [String], network: Network) async throws -> [ActiveWalletModel] {
        let mnemonic = try Mnemonic(mnemonicWords: phrase)
        let keyPair = try MnemonicLegacy.anyMnemonicToPrivateKey(
            mnemonicArray: mnemonic.mnemonicWords
        )
        let currency = (try? currencyService.getActiveCurrency()) ?? .USD
        return try await activeWalletService.loadActiveWallets(
            publicKey: keyPair.publicKey,
            network: network,
            currency: currency
        )
    }

    public func findActiveWallets(publicKey: TonSwift.PublicKey, network: Network) async throws -> [ActiveWalletModel] {
        let currency = (try? currencyService.getActiveCurrency()) ?? .USD
        return try await activeWalletService.loadActiveWallets(
            publicKey: publicKey,
            network: network,
            currency: currency
        )
    }

    public func findActiveWallets(
        accounts: [(id: String, address: Address, revision: WalletContractVersion)],
        network: Network
    ) async throws -> [ActiveWalletModel] {
        let currency = (try? currencyService.getActiveCurrency()) ?? .USD
        return try await activeWalletService.loadActiveWallets(
            accounts: accounts,
            network: network,
            currency: currency
        )
    }
}

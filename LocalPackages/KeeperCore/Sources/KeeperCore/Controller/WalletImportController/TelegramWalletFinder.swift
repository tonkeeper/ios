import Foundation
import KeeperCoreComponents
import KeeperCoreSensitive
import TKLogging
import TonSwift

@frozen public enum TelegramWalletLookup {
    case found(ActiveWalletModel)
    case none
    case failed(Error)
}

protocol TelegramWalletAccountLoader {
    func account(address: Address, network: Network) async throws -> Account
    func publicKey(address: Address, network: Network) async throws -> Data
}

/// Finds the Telegram wallet of a BIP39 phrase.
///
/// Telegram does not deploy the wallet on an incoming transfer, so most of them are `uninit` with funds.
/// An empty `nonexist` address is not offered: from the phrase alone it is indistinguishable from any other.
public final class TelegramWalletFinder {
    static let walletTgInterface = "walletTg"

    private let accountLoader: TelegramWalletAccountLoader
    private let addedWallets: () -> [Wallet]

    init(
        accountLoader: TelegramWalletAccountLoader,
        addedWallets: @escaping () -> [Wallet]
    ) {
        self.accountLoader = accountLoader
        self.addedWallets = addedWallets
    }

    public func find(words: [String], network: Network) async -> TelegramWalletLookup {
        guard BIP39Mnemonic.isValidBip39Mnemonic(mnemonicArray: words) else {
            return .none
        }
        do {
            // A phrase valid as a TON mnemonic too still gets its Telegram key from BIP39.
            let publicKey = try CoreMnemonic(mnemonicWords: words, type: .bip39).toKeyPair().publicKey
            let address = try WalletTg(publicKey: publicKey.data, network: network).address()

            let isAdded = addedWallets().contains { wallet in
                wallet.network == network && wallet.kind != .watchonly && (try? wallet.address) == address
            }
            guard !isAdded else { return .none }

            let account = try await accountLoader.account(address: address, network: network)
            switch account.status {
            case "active" where account.interfaces.contains(Self.walletTgInterface):
                // A different key on the contract means it was rotated and the phrase no longer controls the wallet.
                let contractKey = try await accountLoader.publicKey(address: address, network: network)
                guard contractKey == publicKey.data else { return .none }
            case "uninit" where account.balance > 0:
                break
            default:
                return .none
            }
            return .found(ActiveWalletModel(
                id: address.toRaw(),
                revision: .walletTg,
                address: address,
                isActive: true,
                balance: Balance(tonBalance: TonBalance(amount: account.balance), jettonsBalance: []),
                nfts: [],
                history: .unknown
            ))
        } catch {
            Log.w("Telegram wallet lookup failed: \(error)")
            return .failed(error)
        }
    }
}

struct APITelegramWalletAccountLoader: TelegramWalletAccountLoader {
    let apiProvider: APIProvider

    func account(address: Address, network: Network) async throws -> Account {
        try await apiProvider.api(network).getAccountInfo(accountId: address.toRaw())
    }

    func publicKey(address: Address, network: Network) async throws -> Data {
        try await apiProvider.api(network).getAccountPublicKey(address: address)
    }
}

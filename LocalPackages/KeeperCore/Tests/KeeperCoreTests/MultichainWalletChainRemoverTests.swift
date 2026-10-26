@testable import KeeperCore
import KeeperCoreSensitive
import TonSwift
import XCTest

final class MultichainWalletChainRemoverTests: XCTestCase {
    func test_remove_registersWithoutTheChainsThenSavesTheReducedState() async throws {
        let wallet = makeWallet(addresses: [address(.eth), address(.sol), address(.polygon)])
        var synced = [MultichainWalletState]()
        var saved = [MultichainWallet]()
        let remover = MultichainWalletChainRemover(
            dependencies: MultichainWalletChainRemover.Dependencies(
                getMnemonics: { wallets, _ in
                    wallets.reduce(into: [:]) { result, wallet in
                        result[wallet.id] = CoreMnemonic(mnemonicWords: Array(repeating: "abandon", count: 12), type: .bip39)
                    }
                },
                syncWallet: { _, state in synced.append(state) },
                saveWallet: { _, multichain in saved.append(multichain) }
            )
        )

        try await remover.remove([.sol, .polygon], from: wallet, passcode: "1234")

        let reduced = MultichainWalletState(walletId: "multichain", addresses: [address(.eth)], syncState: .synced)
        XCTAssertEqual(synced, [reduced])
        XCTAssertEqual(saved, [.multichain(reduced)])
    }

    func test_remove_keepsTheStateWhenRegistrationFails() async {
        let wallet = makeWallet(addresses: [address(.eth), address(.sol)])
        var saved = [MultichainWallet]()
        let remover = MultichainWalletChainRemover(
            dependencies: MultichainWalletChainRemover.Dependencies(
                getMnemonics: { wallets, _ in
                    wallets.reduce(into: [:]) { result, wallet in
                        result[wallet.id] = CoreMnemonic(mnemonicWords: Array(repeating: "abandon", count: 12), type: .bip39)
                    }
                },
                syncWallet: { _, _ throws(MultichainServiceError) in throw .connectionError },
                saveWallet: { _, multichain in saved.append(multichain) }
            )
        )

        do {
            try await remover.remove([.sol], from: wallet, passcode: "1234")
            XCTFail("A failed registration must surface")
        } catch {}

        XCTAssertTrue(saved.isEmpty)
    }

    func test_remove_isANoOpWithoutTheChains() async throws {
        let wallet = makeWallet(addresses: [address(.eth)])
        let remover = MultichainWalletChainRemover(
            dependencies: MultichainWalletChainRemover.Dependencies(
                getMnemonics: { _, _ in
                    XCTFail("Nothing to remove, nothing to decrypt")
                    return [:]
                },
                syncWallet: { _, _ in XCTFail("Nothing to remove, nothing to register") },
                saveWallet: { _, _ in XCTFail("Nothing to remove, nothing to save") }
            )
        )

        try await remover.remove([.sol], from: wallet, passcode: "1234")
    }
}

private extension MultichainWalletChainRemoverTests {
    func address(_ chain: MultichainChain) -> MultichainWalletAddress {
        MultichainWalletAddress(
            chain: chain,
            address: "\(chain.rawValue)-address",
            publicKey: MultichainPublicKey(defaultHex: "default-public-key", segWit: "segwit-public-key")
        )
    }

    func makeWallet(addresses: [MultichainWalletAddress]) -> Wallet {
        let publicKey = TonSwift.PublicKey(data: Data(repeating: 1, count: 32))
        return Wallet(
            id: "wallet",
            identity: WalletIdentity(network: .mainnet, kind: .Regular(publicKey, .v5R1)),
            metaData: WalletMetaData(label: "wallet", tintColor: .SteelGray, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings(),
            multichain: .multichain(MultichainWalletState(walletId: "multichain", addresses: addresses, syncState: .synced))
        )
    }
}

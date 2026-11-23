import ChainKit
import CryptoKit
@testable import KeeperCore
import WalletCore
import XCTest

final class LedgerMultichainAccountTests: XCTestCase {
    func testStateMatchesAMnemonicWalletWithTheSameKeys() throws {
        let device = try MnemonicDevice()

        let state = try device.account().wallet(tonPublicKey: device.tonKey.publicKey.rawRepresentation, chains: MultichainChain.displayOrder).state

        let expected = MultichainChain.displayOrder.map { chain in
            let type: ChainKit.Address.Type_ = chain == .ton ? .tonv4r2 : chain == .btc ? .btcsegwit : .default_
            return [
                chain.rawValue,
                device.wallet.getAddress(chain: chain.asChainKitChain, type: type).display,
                device.wallet.getPublicKey(chain: chain.asChainKitChain).defaultHex,
            ]
        }
        XCTAssertEqual(state.addresses.map { [$0.chain.rawValue, $0.address, $0.publicKey?.defaultHex ?? ""] }, expected)
        XCTAssertEqual(state.addresses.first { $0.chain == .btc }?.publicKey?.segWit, device.wallet.getPublicKey(chain: MultichainChain.btc.asChainKitChain).segWit)
        XCTAssertEqual(state.addresses.first { $0.chain == .btc }?.type, .btcP2WPKH)
        XCTAssertEqual(state.addresses.first?.type, .tonV4R2)
        XCTAssertEqual(state.syncState, .pending)
    }

    func testStateContainsOnlyTheNetworksSelectedDuringPairing() throws {
        let device = try MnemonicDevice()
        let chains: [MultichainChain] = [.ton, .base, .tron]

        let state = try device.account().wallet(
            tonPublicKey: device.tonKey.publicKey.rawRepresentation,
            chains: chains
        ).state

        XCTAssertEqual(state.addresses.map(\.chain), chains)
    }

    func testAppKeysCoverOnlyTheChainsTheyReach() throws {
        let device = try MnemonicDevice()

        let addresses = try LedgerAppKeys(tron: device.tronKey(), solana: device.solanaKey()).addresses(chains: MultichainChain.displayOrder)

        XCTAssertEqual(addresses.map(\.chain), [.sol, .tron])
    }

    func testASolanaKeyOfTheWrongSizeIsRefused() {
        XCTAssertThrowsError(try LedgerAppKeys(solana: Data(repeating: 0x01, count: 31)).addresses(chains: [.sol]))
    }

    func testAProofOfAnotherMessageIsRefused() throws {
        let device = try MnemonicDevice()
        let account = try LedgerMultichainAccount(
            proofSignature: device.tonKey.signature(for: Data("another message".utf8)),
            keys: device.account().keys
        )

        XCTAssertThrowsError(try account.wallet(tonPublicKey: device.tonKey.publicKey.rawRepresentation, chains: [.ton, .eth]))
    }

    func testAnAddressTheEVMKeyDoesNotDeriveIsRefused() throws {
        let device = try MnemonicDevice()
        let keys = try LedgerAppKeys(evm: LedgerAppKeys.Key(publicKey: device.evmKey().publicKey, address: String(repeating: "0", count: 40)))

        XCTAssertThrowsError(try keys.addresses(chains: [.eth]))
    }

    func testATronAddressTheKeyDoesNotDeriveIsRefused() throws {
        let device = try MnemonicDevice()
        let keys = try LedgerAppKeys(tron: LedgerAppKeys.Key(publicKey: device.tronKey().publicKey, address: "TNPeeaaFB7K9cmo4uQpcU32zGK8G1NYqeL"))

        XCTAssertThrowsError(try keys.addresses(chains: [.tron]))
    }

    func testAddingNetworksKeepsTheWalletAndAddsOnlyWhatItLacks() throws {
        let device = try MnemonicDevice()
        let evm = try LedgerAppKeys(evm: device.evmKey()).addresses(chains: [.eth, .base])
        let state = MultichainWalletState(walletId: "ledger", addresses: evm, syncState: .pending)

        let networks = try XCTUnwrap(
            state.addingLedgerNetworks(LedgerAppKeys(evm: device.evmKey(), tron: device.tronKey()), chains: [.eth, .base, .tron])
        )

        XCTAssertEqual(networks.added, [.tron])
        XCTAssertEqual(networks.state.walletId, "ledger")
        XCTAssertEqual(networks.state.addresses.map(\.chain), MultichainChain.displayOrder.filter { [.eth, .base, .tron].contains($0) })
        XCTAssertEqual(networks.state.syncState, .synced)
    }

    func testKeysOfNetworksTheWalletHasAddNothing() throws {
        let device = try MnemonicDevice()
        let tron = try LedgerAppKeys(tron: device.tronKey())
        let state = try MultichainWalletState(walletId: "ledger", addresses: tron.addresses(chains: [.tron]), syncState: .synced)

        XCTAssertNil(try state.addingLedgerNetworks(tron, chains: [.tron]))
    }

    func testAnUpgradeThatWouldGainOnlyTonLeavesTheWalletAsItIs() throws {
        let device = try MnemonicDevice()
        let account = try LedgerMultichainAccount(proofSignature: device.account().proofSignature, keys: LedgerAppKeys())

        XCTAssertNil(try account.upgrade(tonPublicKey: device.tonKey.publicKey.rawRepresentation, chains: MultichainChain.displayOrder))
    }

    func testAnUpgradeGainsTheNetworksItsKeysReach() throws {
        let device = try MnemonicDevice()
        let account = try LedgerMultichainAccount(proofSignature: device.account().proofSignature, keys: LedgerAppKeys(tron: device.tronKey()))

        let upgrade = try XCTUnwrap(account.upgrade(tonPublicKey: device.tonKey.publicKey.rawRepresentation, chains: MultichainChain.displayOrder))

        XCTAssertEqual(upgrade.added, [.tron])
        XCTAssertEqual(upgrade.state.addresses.map(\.chain), [.ton, .tron])
        let keyPair = try XCTUnwrap(
            WalletKeyPair.companion.fromPrivateKey(privateKey: upgrade.appPrivateKey.asKotlinByteArray, walletId: upgrade.state.walletId).getOrNull()
        )
        XCTAssertEqual(keyPair.kind, .ledger)
    }
}

/// Answers as a Ledger with the given seed would, so the result can be compared with ChainKit's.
private struct MnemonicDevice {
    let wallet: MnemonicWallet
    let tonKey: Curve25519.Signing.PrivateKey

    init() throws {
        wallet = try CryptoWallet.Companion.shared.fromMnemonic(
            mnemonic_: "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        )
        tonKey = try Curve25519.Signing.PrivateKey(
            rawRepresentation: wallet.getPrivateKey(chain: MultichainChain.ton.asChainKitChain).data().asData
        )
    }

    func account() throws -> LedgerMultichainAccount {
        let proofHash = try XCTUnwrap(
            LedgerWallet.companion.proofHash(tonPublicKey: tonKey.publicKey.rawRepresentation.asKotlinByteArray).getOrNull()
        )
        return try LedgerMultichainAccount(
            proofSignature: tonKey.signature(for: proofHash.asData),
            keys: LedgerAppKeys(evm: evmKey(), tron: tronKey(), solana: solanaKey(), bitcoin: bitcoinXpub())
        )
    }

    /// The Ethereum app reports its address in lowercase, without `0x`.
    func evmKey() throws -> LedgerAppKeys.Key {
        let key = try uncompressedKey(chain: .eth)
        return LedgerAppKeys.Key(publicKey: key, address: String(address(chain: .eth).dropFirst(2)).lowercased())
    }

    func tronKey() throws -> LedgerAppKeys.Key {
        try LedgerAppKeys.Key(publicKey: uncompressedKey(chain: .tron), address: address(chain: .tron))
    }

    /// As the Bitcoin app reports it: `xpub…` of `m/84'/0'/0'`.
    func bitcoinXpub() throws -> String {
        let zpub = wallet.getPublicKey(chain: MultichainChain.btc.asChainKitChain).segWit
        return try XCTUnwrap(BitcoinExtendedKey.converted(zpub, to: BitcoinExtendedKey.xpubVersion))
    }

    func solanaKey() throws -> Data {
        let privateKey = try XCTUnwrap(WalletCore.PrivateKey(data: wallet.getPrivateKey(chain: MultichainChain.sol.asChainKitChain).data().asData))
        return privateKey.getPublicKeyEd25519().data
    }

    private func uncompressedKey(chain: MultichainChain) throws -> Data {
        let privateKey = try XCTUnwrap(WalletCore.PrivateKey(data: wallet.getPrivateKey(chain: chain.asChainKitChain).data().asData))
        return privateKey.getPublicKeySecp256k1(compressed: false).data
    }

    private func address(chain: MultichainChain) -> String {
        wallet.getAddress(chain: chain.asChainKitChain, type: .default_).display
    }
}

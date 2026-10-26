import ChainKit
import Foundation
@testable import KeeperCore
import KeeperCoreSensitive
import TonSwift
import TronSwift
import XCTest

final class LegacySwapWalletTests: XCTestCase {
    private let tonWords = [
        "business", "thunder", "episode", "arena",
        "tray", "twelve", "humble", "asthma",
        "uphold", "pumpkin", "crunch", "fortune",
    ]

    /// The canonical zero-entropy BIP39 vector: a phrase a user can import as a legacy wallet.
    private let bip39Words = [
        "abandon", "abandon", "abandon", "abandon",
        "abandon", "abandon", "abandon", "abandon",
        "abandon", "abandon", "abandon", "about",
    ]

    func test_legacySigningWallet_tonMnemonic_signsWithTheWalletTonKey() throws {
        let mnemonic = CoreMnemonic(mnemonicWords: tonWords, type: .ton)

        let signingWallet = try makeLegacySigningWallet(mnemonic: mnemonic)

        XCTAssertEqual(try signingWallet.publicKey(chain: .ton).defaultHex, try tonPublicKeyHex(mnemonic))
    }

    func test_legacySigningWallet_tonMnemonic_signsWithTheLegacyTronKey() throws {
        let signingWallet = try makeLegacySigningWallet(mnemonic: CoreMnemonic(mnemonicWords: tonWords, type: .ton))

        XCTAssertEqual(try tronAddress(controlledBy: signingWallet), try legacyTron(tonWords).address.base58)
    }

    func test_legacySigningWallet_bip39Mnemonic_signsWithTheWalletTonKey() throws {
        let mnemonic = CoreMnemonic(mnemonicWords: bip39Words, type: .bip39)

        let signingWallet = try makeLegacySigningWallet(mnemonic: mnemonic)

        XCTAssertEqual(try signingWallet.publicKey(chain: .ton).defaultHex, try tonPublicKeyHex(mnemonic))
    }

    /// A BIP39 phrase imported as a legacy wallet keeps the `TonTron` TRON address, which the
    /// BIP44 branch of an HD wallet built from the same phrase does not control.
    func test_legacySigningWallet_bip39Mnemonic_signsWithTheLegacyTronKey() throws {
        let signingWallet = try makeLegacySigningWallet(mnemonic: CoreMnemonic(mnemonicWords: bip39Words, type: .bip39))

        let legacyTronAddress = try legacyTron(bip39Words).address.base58
        XCTAssertEqual(try tronAddress(controlledBy: signingWallet), legacyTronAddress)
        XCTAssertNotEqual(try tronAddress(controlledBy: .hd(makeHDWallet(bip39Words))), legacyTronAddress)
    }

    func test_legacySigningWallet_rejectsATronAddressItsKeyDoesNotControl() throws {
        XCTAssertThrowsError(
            try SwapSigningWallet(
                legacyMnemonic: CoreMnemonic(mnemonicWords: bip39Words, type: .bip39),
                tronAddress: legacyTron(tonWords).address
            )
        )
    }

    func test_legacySigningWallet_hasNoKeysForOtherChains() throws {
        let signingWallet = try makeLegacySigningWallet(mnemonic: CoreMnemonic(mnemonicWords: tonWords, type: .ton))

        for chain in MultichainChain.allCases where chain != .ton && chain != .tron {
            XCTAssertThrowsError(try signingWallet.privateKey(chain: chain), "\(chain)")
        }
    }

    func test_legacySwapWallet_swapsOnTheTonAndTronAddressesUnregisteredWithLegacyKeys() throws {
        for (contractVersion, addressType) in [(WalletContractVersion.v4R2, MultichainWalletAddressType.tonV4R2), (.v5R1, .tonV5R1)] {
            let wallet = try makeWallet(contractVersion: contractVersion)
            let tonAddress = try wallet.friendlyAddress.toString()
            let tronAddress = try XCTUnwrap(wallet.tron).address.base58

            let swapWallet = try XCTUnwrap(wallet.legacySwapWallet)

            XCTAssertEqual(swapWallet.wallet, wallet)
            XCTAssertEqual(swapWallet.registration, .unregistered)
            XCTAssertNil(swapWallet.walletId)
            XCTAssertEqual(swapWallet.keys, .legacy)
            XCTAssertEqual(swapWallet.walletAddress(for: .ton)?.address, tonAddress)
            XCTAssertEqual(swapWallet.walletAddress(for: .ton)?.type, addressType)
            XCTAssertEqual(swapWallet.address(for: .tron), tronAddress)
        }
    }

    func test_legacySwapWallet_ofABip39Wallet_carriesTheAddressesTheLegacyKeysControl() throws {
        let mnemonic = CoreMnemonic(mnemonicWords: bip39Words, type: .bip39)
        let wallet = try makeWallet(contractVersion: .v5R1, mnemonic: mnemonic)

        let swapWallet = try XCTUnwrap(wallet.legacySwapWallet)
        let signingWallet = try SwapSigningWallet(
            legacyMnemonic: mnemonic,
            tronAddress: TronSwift.Address(address: XCTUnwrap(swapWallet.address(for: .tron)))
        )

        XCTAssertEqual(swapWallet.address(for: .tron), try tronAddress(controlledBy: signingWallet))
        XCTAssertEqual(
            swapWallet.walletAddress(for: .ton)?.publicKey?.defaultHex,
            try signingWallet.publicKey(chain: .ton).defaultHex
        )
    }

    func test_legacySwapWallet_isUnavailableForWalletsTheSwapCannotSignFor() throws {
        XCTAssertNil(try makeWallet(contractVersion: .v3R2).legacySwapWallet)
        XCTAssertNil(try makeWallet(contractVersion: .v4R1).legacySwapWallet)
        XCTAssertNil(try makeWallet(contractVersion: .v5Beta).legacySwapWallet)
        XCTAssertNil(try makeWallet(contractVersion: .v4R2, network: .testnet).legacySwapWallet)
        XCTAssertNil(try makeWallet(contractVersion: .v4R2, hasTron: false).legacySwapWallet)
        XCTAssertNil(try makeWallet(contractVersion: .v4R2, multichain: .multichain(registeredState())).legacySwapWallet)
    }

    func test_registeredSwapWallet_swapsOnTheRegisteredStateWithHdKeys() throws {
        let state = registeredState()
        let wallet = try makeWallet(contractVersion: .v4R2, multichain: .multichain(state))

        let swapWallet = MultichainSwapWallet(wallet: wallet, registeredState: state)

        XCTAssertEqual(swapWallet.wallet, wallet)
        XCTAssertEqual(swapWallet.registration, .registered(walletId: "registered"))
        XCTAssertEqual(swapWallet.walletId, "registered")
        XCTAssertEqual(swapWallet.keys, .hd)
        XCTAssertEqual(swapWallet.addresses, state.addresses)
        XCTAssertEqual(swapWallet.walletAddress(for: .ton)?.type, .tonV4R2)
        XCTAssertEqual(swapWallet.address(for: .tron), "TMultichainTronAddress")
    }
}

private extension LegacySwapWalletTests {
    func makeLegacySigningWallet(mnemonic: CoreMnemonic) throws -> SwapSigningWallet {
        try SwapSigningWallet(
            legacyMnemonic: mnemonic,
            tronAddress: legacyTron(mnemonic.mnemonicWords).address
        )
    }

    func makeHDWallet(_ words: [String]) throws -> CryptoWallet {
        try CryptoWallet.Companion.shared.fromMnemonic(mnemonic_: words.joined(separator: " "))
    }

    func legacyTron(_ words: [String]) throws -> WalletTron {
        try XCTUnwrap(WalletTron(tonMnemonic: words))
    }

    func tonPublicKeyHex(_ mnemonic: CoreMnemonic) throws -> String {
        try "0x" + hex(mnemonic.toKeyPair().publicKey.data)
    }

    func tronAddress(controlledBy signingWallet: SwapSigningWallet) throws -> String {
        let rawKey = try signingWallet.privateKey(chain: .tron).data().asData
        let publicKey = TronSwift.PrivateKey(data: rawKey, chainCode: Data())
            .publicKey(compressed: false, curve: Secp256k1DerivationCurve())
        return try TronSwift.Address(publicKey: publicKey).base58
    }

    func hex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    func registeredState() -> MultichainWalletState {
        MultichainWalletState(
            walletId: "registered",
            addresses: [
                MultichainWalletAddress(chain: .ton, address: "UQMultichainTonV5R1", type: .tonV5R1),
                MultichainWalletAddress(chain: .ton, address: "UQMultichainTonV4R2", type: .tonV4R2),
                MultichainWalletAddress(chain: .tron, address: "TMultichainTronAddress"),
            ]
        )
    }

    func makeWallet(
        contractVersion: WalletContractVersion,
        network: KeeperCore.Network = .mainnet,
        hasTron: Bool = true,
        mnemonic: CoreMnemonic? = nil,
        multichain: MultichainWallet? = nil
    ) throws -> Wallet {
        let mnemonic = mnemonic ?? CoreMnemonic(mnemonicWords: tonWords, type: .ton)
        let keyPair = try mnemonic.toKeyPair()
        return Wallet(
            id: "legacy-wallet",
            identity: WalletIdentity(network: network, kind: .Regular(keyPair.publicKey, contractVersion)),
            metaData: WalletMetaData(label: "legacy", tintColor: .SteelGray, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings(),
            tron: hasTron ? WalletTron(tonMnemonic: mnemonic.mnemonicWords) : nil,
            multichain: multichain
        )
    }
}

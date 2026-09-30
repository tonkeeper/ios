import ChainKit
@testable import KeeperCore
import KeeperCoreComponents
import KeeperCoreSensitive
import TonSwift
import XCTest

/// Create-multichain always stamps `.currentVersion` (.v5R1 / W5) on the TON identity.
/// Enrichment runs for .bip39 when multichain flag is on; `guessByWords` prefers `.ton` for ambiguous phrases.
final class MultichainCreateMnemonicClassificationTests: XCTestCase {
    func test_chainKitB128Mnemonic_isTwelveWords() throws {
        let words = try generateChainKitB128Words()
        XCTAssertEqual(words.count, 12)
        XCTAssertTrue(
            DerivationType.guessByWords(words) == .bip39
                || DerivationType.isAmbiguous(words),
            "ChainKit b128 phrase must be bip39 (or ambiguous with ton)"
        )
    }

    func test_screenshotPhrase_isAmbiguousAndGuessedAsTon() {
        // Captured from a multichain create backup screen on 2026-07-17.
        let words = [
            "shock", "similar", "crowd", "solve",
            "pulse", "split", "exchange", "vehicle",
            "gift", "suggest", "power", "release",
        ]
        XCTAssertTrue(TonSwift.Mnemonic.mnemonicValidate(mnemonicArray: words))
        XCTAssertTrue(BIP39Mnemonic.isValidBip39Mnemonic(mnemonicArray: words))
        XCTAssertTrue(DerivationType.isAmbiguous(words))
        XCTAssertEqual(DerivationType.guessByWords(words), .ton)
    }

    func test_ambiguousPhrase_classifiedAsTon_enricherMarksUnavailable() async {
        let words = [
            "business", "thunder", "episode", "arena",
            "tray", "twelve", "humble", "asthma",
            "uphold", "pumpkin", "crunch", "fortune",
        ]
        XCTAssertEqual(DerivationType.guessByWords(words), .ton)
        XCTAssertTrue(DerivationType.isAmbiguous(words))

        let wallet = makeWallet(id: "ambiguous-wallet", contractVersion: .v5R1)
        let persistenceSpy = MultichainCreatePersistenceSpy()
        let enricher = MultichainWalletEnricherImplementation(
            dependencies: MultichainWalletEnricherDependencies(
                supportedChains: [.ton, .eth, .btc],
                getWallets: { [wallet] },
                getMnemonics: { _, _ in
                    [wallet.id: CoreMnemonic(mnemonicWords: words, type: .guessByWords(words))]
                },
                deriveWallet: { _ in
                    XCTFail("ton-classified mnemonic must not be derived as multichain")
                    return MultichainWalletState(walletId: "unexpected", addresses: [])
                },
                saveWallet: persistenceSpy.saveWallet
            )
        )

        await enricher.enrichMissingWallets(passcode: "0000")

        XCTAssertEqual(persistenceSpy.savedMultichainWallets, [.unavailable])
        let enriched = makeWallet(
            id: wallet.id,
            contractVersion: .v5R1,
            multichain: .unavailable
        )
        XCTAssertFalse(enriched.isMultichain)
        XCTAssertTrue(enriched.isW5)
    }

    func test_createPathStampsCurrentVersionW5_evenWhenMultichainEnriched() {
        XCTAssertEqual(WalletContractVersion.currentVersion, .v5R1)

        let wallet = makeWallet(
            id: "mc-wallet",
            contractVersion: WalletContractVersion.currentVersion,
            multichain: .multichain(
                MultichainWalletState(
                    walletId: "mc",
                    addresses: [
                        .init(chain: .ton, address: "EQ...", type: .tonV5R1),
                        .init(chain: .eth, address: "0xabc"),
                    ]
                )
            )
        )

        XCTAssertTrue(wallet.isMultichain)
        XCTAssertTrue(wallet.isW5)
    }

    func test_forcedBip39_allowsEnrichmentForAmbiguousPhrase() async {
        let words = [
            "business", "thunder", "episode", "arena",
            "tray", "twelve", "humble", "asthma",
            "uphold", "pumpkin", "crunch", "fortune",
        ]
        let wallet = makeWallet(id: "forced-bip39", contractVersion: .v5R1)
        let persistenceSpy = MultichainCreatePersistenceSpy()
        let enricher = MultichainWalletEnricherImplementation(
            dependencies: MultichainWalletEnricherDependencies(
                supportedChains: [.eth],
                getWallets: { [wallet] },
                getMnemonics: { _, _ in
                    [wallet.id: CoreMnemonic(mnemonicWords: words, type: .bip39)]
                },
                deriveWallet: { _ in
                    MultichainWalletState(
                        walletId: "derived",
                        addresses: [.init(chain: .eth, address: "0xderived")]
                    )
                },
                saveWallet: persistenceSpy.saveWallet
            )
        )

        await enricher.enrichMissingWallets(passcode: "0000")

        XCTAssertEqual(
            persistenceSpy.savedMultichainWallets,
            [
                .multichain(
                    MultichainWalletState(
                        walletId: "derived",
                        addresses: [.init(chain: .eth, address: "0xderived")],
                        syncState: .pending
                    )
                ),
            ]
        )
    }
}

private final class MultichainCreatePersistenceSpy {
    private(set) var savedMultichainWallets = [MultichainWallet]()

    func saveWallet(wallet _: Wallet, multichain: MultichainWallet) async {
        savedMultichainWallets.append(multichain)
    }
}

private extension MultichainCreateMnemonicClassificationTests {
    func generateChainKitB128Words() throws -> [String] {
        var mnemonicWords: [String]?
        Mnemonic(
            value: MnemonicGenerator.shared.generateFrom(size: .b128)
        ).toWords().useAndClear { words in
            for index in 0 ..< words.size {
                guard let word = words.get(index: index) as? String else {
                    mnemonicWords = nil
                    return
                }
                if mnemonicWords == nil {
                    mnemonicWords = []
                }
                mnemonicWords?.append(word)
            }
        }
        guard let mnemonicWords else {
            throw NSError(domain: "MultichainCreateMnemonicClassificationTests", code: 1)
        }
        return mnemonicWords
    }

    func makeWallet(
        id: String,
        contractVersion: WalletContractVersion,
        multichain: MultichainWallet? = nil
    ) -> Wallet {
        let publicKeyData = Data((id + "-public-key").utf8) + Data(repeating: 0, count: 32)
        let publicKey = TonSwift.PublicKey(data: Data(publicKeyData.prefix(32)))
        return Wallet(
            id: id,
            identity: WalletIdentity(network: .mainnet, kind: .Regular(publicKey, contractVersion)),
            metaData: WalletMetaData(label: id, tintColor: .SteelGray, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings(),
            multichain: multichain
        )
    }
}

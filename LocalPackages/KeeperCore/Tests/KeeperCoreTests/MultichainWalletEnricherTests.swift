@testable import KeeperCore
import KeeperCoreSensitive
import TonSwift
import XCTest

final class MultichainWalletEnricherTests: XCTestCase {
    func test_enrichMissingWallets_loadsMnemonicsInSingleBatchAndSavesPendingState() async {
        let firstWallet = makeWallet(id: "first-wallet")
        let secondWallet = makeWallet(
            id: "second-wallet",
            multichain: .multichain(
                MultichainWalletState(
                    walletId: "second-wallet-multichain",
                    addresses: [
                        MultichainWalletAddress(chain: .eth, address: "0xexisting"),
                    ]
                )
            )
        )
        let testnetWallet = makeWallet(id: "testnet-wallet", network: .testnet)
        let unavailableWallet = makeWallet(id: "unavailable-wallet", multichain: .unavailable)
        let mnemonicsSpy = MultichainMnemonicsSpy(
            mnemonics: [
                firstWallet.id: CoreMnemonic(
                    mnemonicWords: Array(repeating: "abandon", count: 12),
                    type: .bip39
                ),
                secondWallet.id: CoreMnemonic(
                    mnemonicWords: Array(repeating: "ability", count: 12),
                    type: .bip39
                ),
            ]
        )
        let persistenceSpy = MultichainPersistenceSpy()
        let enricher = MultichainWalletEnricherImplementation(
            dependencies: MultichainWalletEnricherDependencies(
                supportedChains: [.eth, .btc],
                getWallets: {
                    [
                        firstWallet,
                        secondWallet,
                        testnetWallet,
                        unavailableWallet,
                    ]
                },
                getMnemonics: mnemonicsSpy.getMnemonics,
                deriveWallet: { _ in
                    MultichainWalletState(
                        walletId: "derived-wallet-id",
                        addresses: [
                            self.makeAddress(chain: .eth, address: "0xderived"),
                            self.makeAddress(chain: .btc, address: "bc1derived", type: .btcP2WPKH),
                        ]
                    )
                },
                saveWallet: persistenceSpy.saveWallet
            )
        )

        await enricher.enrichMissingWallets(passcode: "1234")

        XCTAssertEqual(
            mnemonicsSpy.requestedWalletIds,
            [[firstWallet.id, secondWallet.id]]
        )
        XCTAssertEqual(
            persistenceSpy.savedWalletIds,
            [firstWallet.id, secondWallet.id]
        )
        XCTAssertEqual(
            persistenceSpy.savedMultichainWallets,
            [
                .multichain(
                    MultichainWalletState(
                        walletId: "derived-wallet-id",
                        addresses: [
                            self.makeAddress(chain: .eth, address: "0xderived"),
                            self.makeAddress(chain: .btc, address: "bc1derived", type: .btcP2WPKH),
                        ],
                        syncState: .pending
                    )
                ),
                .multichain(
                    MultichainWalletState(
                        walletId: "derived-wallet-id",
                        addresses: [
                            self.makeAddress(chain: .eth, address: "0xderived"),
                            self.makeAddress(chain: .btc, address: "bc1derived", type: .btcP2WPKH),
                        ],
                        syncState: .pending
                    )
                ),
            ]
        )
    }

    func test_enrichMissingWallets_savesUnavailableForUnsupportedMnemonic() async {
        let wallet = makeWallet(id: "wallet")
        let mnemonicsSpy = MultichainMnemonicsSpy(
            mnemonics: [
                wallet.id: CoreMnemonic(
                    mnemonicWords: Array(repeating: "abandon", count: 12),
                    type: .ton
                ),
            ]
        )
        let persistenceSpy = MultichainPersistenceSpy()
        let enricher = MultichainWalletEnricherImplementation(
            dependencies: MultichainWalletEnricherDependencies(
                supportedChains: [.eth, .btc],
                getWallets: {
                    [
                        wallet,
                    ]
                },
                getMnemonics: mnemonicsSpy.getMnemonics,
                deriveWallet: { _ in
                    XCTFail("Unsupported mnemonic must not be derived")
                    return MultichainWalletState(walletId: "unexpected", addresses: [])
                },
                saveWallet: persistenceSpy.saveWallet
            )
        )

        await enricher.enrichMissingWallets(passcode: "1234")

        XCTAssertEqual(persistenceSpy.savedWalletIds, [wallet.id])
        XCTAssertEqual(persistenceSpy.savedMultichainWallets, [.unavailable])
    }

    func test_enrichMissingWalletsSavesOnlyPreferredTONAddressType() async {
        let v4Wallet = makeWallet(id: "v4-wallet", contractVersion: .v4R2)
        let v5Wallet = makeWallet(id: "v5-wallet", contractVersion: .v5R1)
        let mnemonicsSpy = MultichainMnemonicsSpy(
            mnemonics: [
                v4Wallet.id: CoreMnemonic(
                    mnemonicWords: Array(repeating: "abandon", count: 12),
                    type: .bip39
                ),
                v5Wallet.id: CoreMnemonic(
                    mnemonicWords: Array(repeating: "ability", count: 12),
                    type: .bip39
                ),
            ]
        )
        let persistenceSpy = MultichainPersistenceSpy()
        let enricher = MultichainWalletEnricherImplementation(
            dependencies: MultichainWalletEnricherDependencies(
                supportedChains: [.ton],
                getWallets: { [v4Wallet, v5Wallet] },
                getMnemonics: mnemonicsSpy.getMnemonics,
                deriveWallet: { _ in
                    MultichainWalletState(
                        walletId: "derived-wallet-id",
                        addresses: [
                            self.makeAddress(chain: .ton, address: "ton-v4", type: .tonV4R2),
                            self.makeAddress(chain: .ton, address: "ton-v5", type: .tonV5R1),
                        ]
                    )
                },
                saveWallet: persistenceSpy.saveWallet
            )
        )

        await enricher.enrichMissingWallets(passcode: "1234")

        XCTAssertEqual(
            persistenceSpy.savedMultichainWallets,
            [
                .multichain(
                    MultichainWalletState(
                        walletId: "derived-wallet-id",
                        addresses: [self.makeAddress(chain: .ton, address: "ton-v4", type: .tonV4R2)]
                    )
                ),
                .multichain(
                    MultichainWalletState(
                        walletId: "derived-wallet-id",
                        addresses: [self.makeAddress(chain: .ton, address: "ton-v5", type: .tonV5R1)]
                    )
                ),
            ]
        )

        let enrichedWallets = [
            makeWallet(
                id: v4Wallet.id,
                contractVersion: .v4R2,
                multichain: persistenceSpy.savedMultichainWallets[0]
            ),
            makeWallet(
                id: v5Wallet.id,
                contractVersion: .v5R1,
                multichain: persistenceSpy.savedMultichainWallets[1]
            ),
        ]
        let recheck = MultichainWalletEnricherImplementation(
            dependencies: MultichainWalletEnricherDependencies(
                supportedChains: [.ton],
                getWallets: { enrichedWallets },
                getMnemonics: { _, _ in [:] },
                deriveWallet: { _ in
                    XCTFail("Enriched wallets must not be derived again")
                    return MultichainWalletState(walletId: "unexpected", addresses: [])
                },
                saveWallet: { _, _ in }
            )
        )

        XCTAssertFalse(recheck.needsStartupEnrichment)
    }

    func test_needsStartupEnrichment_whenRequiredAddressHasNoPublicKey() {
        let wallet = makeWallet(
            id: "legacy-wallet",
            multichain: .multichain(
                MultichainWalletState(
                    walletId: "multichain-wallet-id",
                    addresses: [.init(chain: .eth, address: "0xlegacy")]
                )
            )
        )
        let enricher = MultichainWalletEnricherImplementation(
            dependencies: MultichainWalletEnricherDependencies(
                supportedChains: [.eth],
                getWallets: { [wallet] },
                getMnemonics: { _, _ in [:] },
                deriveWallet: { _ in
                    XCTFail("Wallet must not be derived while checking enrichment")
                    return MultichainWalletState(walletId: "unexpected", addresses: [])
                },
                saveWallet: { _, _ in }
            )
        )

        XCTAssertTrue(enricher.needsStartupEnrichment)
    }
}

private final class MultichainMnemonicsSpy {
    private let mnemonics: [CoreMnemonicIdentifier: CoreMnemonic]
    private(set) var requestedWalletIds = [[String]]()

    init(mnemonics: [CoreMnemonicIdentifier: CoreMnemonic]) {
        self.mnemonics = mnemonics
    }

    func getMnemonics(
        wallets: [Wallet],
        passcode _: String
    ) async throws -> [CoreMnemonicIdentifier: CoreMnemonic] {
        requestedWalletIds.append(wallets.map(\.id))
        return wallets.reduce(into: [:]) { result, wallet in
            result[wallet.id] = mnemonics[wallet.id]
        }
    }
}

private final class MultichainPersistenceSpy {
    private(set) var savedWalletIds = [String]()
    private(set) var savedMultichainWallets = [MultichainWallet]()

    func saveWallet(wallet: Wallet, multichain: MultichainWallet) async {
        savedWalletIds.append(wallet.id)
        savedMultichainWallets.append(multichain)
    }
}

private extension MultichainWalletEnricherTests {
    func makeAddress(
        chain: MultichainChain,
        address: String,
        type: MultichainWalletAddressType? = nil
    ) -> MultichainWalletAddress {
        MultichainWalletAddress(
            chain: chain,
            address: address,
            type: type,
            publicKey: MultichainPublicKey(
                defaultHex: "default-public-key",
                segWit: "segwit-public-key"
            )
        )
    }

    func makeWallet(
        id: String,
        network: Network = .mainnet,
        contractVersion: WalletContractVersion = .v4R2,
        multichain: MultichainWallet? = nil
    ) -> Wallet {
        let publicKeyData = Data((id + "-public-key").utf8) + Data(repeating: 0, count: 32)
        let publicKey = TonSwift.PublicKey(data: Data(publicKeyData.prefix(32)))
        return Wallet(
            id: id,
            identity: WalletIdentity(network: network, kind: .Regular(publicKey, contractVersion)),
            metaData: WalletMetaData(label: id, tintColor: .SteelGray, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings(),
            multichain: multichain
        )
    }
}

@testable import App
@testable import KeeperCore
import TonSwift
import XCTest

final class WalletMigrationVisibilityTests: XCTestCase {
    func test_unavailableWalletRemainsEligibleAsLegacyMigrationSource() {
        let legacyWallet = makeWallet(id: "legacy", multichain: .unavailable)
        let multichainWallet = makeWallet(
            id: "multichain",
            multichain: .multichain(
                MultichainWalletState(
                    walletId: "multichain",
                    addresses: [
                        MultichainWalletAddress(chain: .ton, address: "ton-address"),
                    ]
                )
            )
        )

        XCTAssertTrue(WalletMigrationVisibility.isLegacyTonWallet(legacyWallet))
        XCTAssertTrue(
            WalletMigrationVisibility.shouldShowMigrationSection(
                wallet: multichainWallet,
                wallets: [legacyWallet, multichainWallet]
            )
        )
    }

    func test_migrationSectionIsHiddenForNonMultichainWallet() {
        let legacyWallet = makeWallet(id: "legacy", multichain: .unavailable)

        XCTAssertFalse(
            WalletMigrationVisibility.shouldShowMigrationSection(
                wallet: legacyWallet,
                wallets: [legacyWallet]
            )
        )
    }

    func test_legacyTonWalletCountIsLocal() {
        let legacyWallet = makeWallet(id: "legacy", multichain: .unavailable)
        let emptyLegacyWallet = makeWallet(id: "empty-legacy", multichain: .none)
        let multichainWallet = makeWallet(
            id: "multichain",
            multichain: .multichain(
                MultichainWalletState(
                    walletId: "multichain",
                    addresses: [
                        MultichainWalletAddress(chain: .ton, address: "ton-address"),
                    ]
                )
            )
        )

        XCTAssertEqual(
            WalletMigrationVisibility.legacyTonWalletCount(
                wallets: [legacyWallet, emptyLegacyWallet, multichainWallet]
            ),
            2
        )
    }

    func test_hasMigratableLegacyWalletsUsesBackendAssets() async {
        let legacyWallet = makeWallet(id: "legacy", multichain: .unavailable)
        let emptyLegacyWallet = makeWallet(id: "empty-legacy", multichain: .unavailable)
        let service = MigrationCountStubService(
            values: [
                WalletMigrationWalletValue(account: "legacy", balance: 1, jettonsCount: 0, nftCount: 0),
                WalletMigrationWalletValue(account: "empty-legacy", balance: 0, jettonsCount: 0, nftCount: 0),
            ]
        )

        let hasMigratable = await WalletMigrationVisibility.hasMigratableLegacyWallets(
            wallets: [legacyWallet, emptyLegacyWallet],
            walletMigrationService: service,
            currency: .USD
        )
        XCTAssertTrue(hasMigratable)

        let emptyOnly = await WalletMigrationVisibility.hasMigratableLegacyWallets(
            wallets: [emptyLegacyWallet],
            walletMigrationService: service,
            currency: .USD
        )
        XCTAssertFalse(emptyOnly)
    }
}

private extension WalletMigrationVisibilityTests {
    func makeWallet(
        id: String,
        multichain: MultichainWallet?
    ) -> Wallet {
        Wallet(
            id: id,
            identity: WalletIdentity(
                network: .mainnet,
                kind: .Regular(
                    TonSwift.PublicKey(data: Data(repeating: 1, count: 32)),
                    .v4R2
                )
            ),
            metaData: WalletMetaData(
                label: id,
                tintColor: .defaultColor,
                icon: .icon(.wallet)
            ),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings(),
            multichain: multichain
        )
    }
}

private final class MigrationCountStubService: WalletMigrationService {
    private let values: [WalletMigrationWalletValue]

    init(values: [WalletMigrationWalletValue]) {
        self.values = values
    }

    func prepareMigration(
        from sourceWallet: Wallet,
        to destinationWallet: Wallet,
        currency: Currency
    ) async throws -> WalletMigrationPrepareResult {
        fatalError("unused")
    }

    func prepareTronMigration(
        from sourceWallet: Wallet,
        to destinationWallet: Wallet
    ) async throws -> WalletMigrationTronPrepareResult? {
        nil
    }

    func availableBatteryCharges(wallet: Wallet) async -> Int? {
        nil
    }

    func getMigrationWallets(
        wallets: [Wallet],
        currency: Currency
    ) async throws -> [WalletMigrationWalletValue] {
        values.filter { value in
            wallets.contains { wallet in
                wallet.id == value.account
            }
        }
    }
}

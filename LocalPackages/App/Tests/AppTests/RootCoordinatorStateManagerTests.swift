@testable import App
@testable import KeeperCore
import TonSwift
import XCTest

final class RootCoordinatorStateManagerTests: XCTestCase {
    func test_rnMigrationDoesNotOpenMainBeforeStartupWorkCompletes() async {
        let keeperInfoStore = KeeperInfoStore(
            keeperInfoRepository: KeeperInfoRepositoryMock()
        )
        let walletsStore = WalletsStore(keeperInfoStore: keeperInfoStore)
        let stateManager = RootCoordinatorStateManager(walletsStore: walletsStore)

        XCTAssertEqual(stateManager.state, .onboarding)

        let wallet = makeWallet()
        _ = await keeperInfoStore.updateKeeperInfo { _ in
            KeeperInfo(
                wallets: [wallet],
                currentWallet: wallet,
                currency: .defaultCurrency,
                securitySettings: SecuritySettings(isBiometryEnabled: false, isLockScreen: false),
                appSettings: KeeperInfo.AppSettings(
                    isSecureMode: false,
                    searchEngine: .duckduckgo
                ),
                country: .auto
            )
        }

        let reloaded = expectation(description: "Wallets reloaded")
        stateManager.reloadWalletsAfterRNMigration {
            reloaded.fulfill()
        }
        await fulfillment(of: [reloaded], timeout: 1)

        XCTAssertEqual(stateManager.state, .onboarding)

        stateManager.didPerformRNMigration()

        XCTAssertEqual(stateManager.state, .main)
    }
}

private extension RootCoordinatorStateManagerTests {
    func makeWallet() -> Wallet {
        Wallet(
            id: "wallet",
            identity: WalletIdentity(
                network: .mainnet,
                kind: .Regular(
                    TonSwift.PublicKey(data: Data(repeating: 1, count: 32)),
                    .v4R2
                )
            ),
            metaData: WalletMetaData(
                label: "Wallet",
                tintColor: .defaultColor,
                icon: .icon(.wallet)
            ),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings()
        )
    }
}

private final class KeeperInfoRepositoryMock: KeeperInfoRepository {
    enum Error: Swift.Error {
        case noKeeperInfo
    }

    private var keeperInfo: KeeperInfo?

    func getKeeperInfo() throws -> KeeperInfo {
        guard let keeperInfo else {
            throw Error.noKeeperInfo
        }
        return keeperInfo
    }

    func saveKeeperInfo(_ keeperInfo: KeeperInfo) throws {
        self.keeperInfo = keeperInfo
    }

    func removeKeeperInfo() throws {
        keeperInfo = nil
    }
}

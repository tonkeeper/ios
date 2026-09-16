@testable import App
@testable import KeeperCore
import TonSwift
import XCTest

@MainActor
final class WalletContainerViewModelTests: XCTestCase {
    /// A wallet imported as multichain gets its addresses only after enrichment, so the top bar has to
    /// refresh on that update — the settings screen is opened with the wallet the top bar hands over.
    func test_settingsWalletFollowsMultichainEnrichment() async throws {
        let wallet = makeWallet()
        let (viewModel, walletsStore) = makeViewModel(wallet: wallet)

        var topBarModel: WalletContainerTopBarModel?
        var modelUpdatesCount = 0
        viewModel.didUpdateModel = {
            topBarModel = $0
            modelUpdatesCount += 1
        }
        var settingsWallet: Wallet?
        viewModel.didTapSettingsButton = { settingsWallet = $0 }

        viewModel.viewDidLoad()
        XCTAssertEqual(modelUpdatesCount, 1)

        await walletsStore.setWalletMultichain(wallet: wallet, multichain: .multichain(makeMultichainState()))
        await waitUntil { modelUpdatesCount == 2 }

        try XCTUnwrap(topBarModel).settingsButton.action()
        XCTAssertEqual(settingsWallet?.isMultichain, true)
    }
}

private extension WalletContainerViewModelTests {
    func makeViewModel(wallet: Wallet) -> (WalletContainerViewModelImplementation, WalletsStore) {
        let repository = KeeperInfoRepositoryMock(
            keeperInfo: KeeperInfo(
                wallets: [wallet],
                currentWallet: wallet,
                currency: .defaultCurrency,
                securitySettings: SecuritySettings(isBiometryEnabled: false, isLockScreen: false),
                appSettings: KeeperInfo.AppSettings(isSecureMode: false, searchEngine: .duckduckgo),
                country: .auto
            )
        )
        let walletsStore = WalletsStore(keeperInfoStore: KeeperInfoStore(keeperInfoRepository: repository))
        return (WalletContainerViewModelImplementation(walletsStore: walletsStore), walletsStore)
    }

    func makeWallet() -> Wallet {
        Wallet(
            id: "imported",
            identity: WalletIdentity(
                network: .mainnet,
                kind: .Regular(TonSwift.PublicKey(data: Data(repeating: 1, count: 32)), .v5R1)
            ),
            metaData: WalletMetaData(label: "Wallet", tintColor: .defaultColor, icon: .emoji("🙂")),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings()
        )
    }

    func makeMultichainState() -> MultichainWalletState {
        MultichainWalletState(
            walletId: "imported",
            addresses: [MultichainWalletAddress(chain: .ton, address: "ton-address", type: .tonV5R1)]
        )
    }

    func waitUntil(
        timeout: TimeInterval = 2,
        condition: @escaping () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        if !condition() {
            XCTFail("Timed out waiting for the top bar to pick up the multichain state")
        }
    }
}

private final class KeeperInfoRepositoryMock: KeeperInfoRepository {
    var keeperInfo: KeeperInfo?

    init(keeperInfo: KeeperInfo?) {
        self.keeperInfo = keeperInfo
    }

    func getKeeperInfo() throws -> KeeperInfo {
        guard let keeperInfo else {
            throw TestError.noKeeperInfo
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

private enum TestError: Error {
    case noKeeperInfo
}

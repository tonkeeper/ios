@testable import KeeperCore
import TonSwift
import XCTest

final class WalletsStoreMultichainTests: XCTestCase {
    /// Create-time race: push auto-enable flips `isOn` on disk while enrichment still holds the
    /// pre-enable wallet snapshot. Writing that snapshot through `setWalletMultichain` must not
    /// put notifications back to off.
    func test_setWalletMultichain_preservesNotificationsIsOnAgainstStaleSnapshot() async {
        let wallet = makeWallet(notificationsIsOn: false)
        let repository = InMemoryKeeperInfoRepository(
            info: makeKeeperInfo(wallet: wallet)
        )
        let keeperInfoStore = KeeperInfoStore(keeperInfoRepository: repository)
        let walletsStore = WalletsStore(keeperInfoStore: keeperInfoStore)

        _ = await keeperInfoStore.updateKeeperInfo { info in
            info?.updateWallet(wallet, notificationsIsOn: true)
        }

        let staleSnapshot = wallet
        XCTAssertFalse(staleSnapshot.notificationSettings.isOn)

        let multichain = MultichainWallet.multichain(
            MultichainWalletState(walletId: "mc-1", addresses: [], syncState: .pending)
        )
        _ = await walletsStore.setWalletMultichain(wallet: staleSnapshot, multichain: multichain)

        let stored = walletsStore.getWallet(id: wallet.id)
        XCTAssertEqual(stored?.notificationSettings.isOn, true)
        guard case let .multichain(state) = stored?.multichain else {
            return XCTFail("expected multichain state")
        }
        XCTAssertEqual(state.walletId, "mc-1")
        XCTAssertEqual(state.syncState, .pending)
    }
}

private extension WalletsStoreMultichainTests {
    func makeWallet(notificationsIsOn: Bool) -> Wallet {
        let publicKey = PublicKey(data: Data(repeating: 0x01, count: 32))
        return Wallet(
            id: "wallet",
            identity: WalletIdentity(network: .mainnet, kind: .Regular(publicKey, .v5R1)),
            metaData: WalletMetaData(
                label: "Test",
                tintColor: .defaultColor,
                icon: .icon(.wallet)
            ),
            setupSettings: WalletSetupSettings(isSetupFinished: true),
            notificationSettings: NotificationSettings(isOn: notificationsIsOn, dapps: [:]),
            batterySettings: BatterySettings()
        )
    }

    func makeKeeperInfo(wallet: Wallet) -> KeeperInfo {
        KeeperInfo(
            wallets: [wallet],
            currentWallet: wallet,
            currency: .defaultCurrency,
            securitySettings: SecuritySettings(isBiometryEnabled: false, isLockScreen: false),
            appSettings: KeeperInfo.AppSettings(
                isSecureMode: false,
                searchEngine: .duckduckgo,
                hidesDustBalances: false
            ),
            country: .auto
        )
    }
}

private final class InMemoryKeeperInfoRepository: KeeperInfoRepository {
    private var info: KeeperInfo?

    init(info: KeeperInfo?) {
        self.info = info
    }

    func getKeeperInfo() throws -> KeeperInfo {
        guard let info else {
            throw InMemoryKeeperInfoRepositoryError.missing
        }
        return info
    }

    func saveKeeperInfo(_ keeperInfo: KeeperInfo) throws {
        info = keeperInfo
    }

    func removeKeeperInfo() throws {
        info = nil
    }
}

private enum InMemoryKeeperInfoRepositoryError: Error {
    case missing
}

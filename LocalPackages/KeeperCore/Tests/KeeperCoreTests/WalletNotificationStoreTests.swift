@testable import KeeperCore
import TonSwift
import XCTest

final class WalletNotificationStoreTests: XCTestCase {
    func test_setDappNotifications_updatesRequestedWalletWithoutCopyingCurrentWalletSettings() async {
        let currentWallet = makeWallet(
            id: "current",
            dapps: ["current.example": true]
        )
        let requestedWallet = makeWallet(
            id: "requested",
            dapps: ["existing.example": true]
        )
        let keeperInfoStore = KeeperInfoStore(
            keeperInfoRepository: WalletNotificationKeeperInfoRepository(
                info: makeKeeperInfo(
                    wallets: [currentWallet, requestedWallet],
                    currentWallet: currentWallet
                )
            )
        )
        let store = WalletNotificationStore(keeperInfoStore: keeperInfoStore)

        await store.setNotificationsIsOn(
            false,
            wallet: requestedWallet,
            dappHost: "new.example"
        )

        let wallets = keeperInfoStore.getState()?.wallets
        XCTAssertEqual(
            wallets?.first(where: { $0.id == currentWallet.id })?.notificationSettings.dapps,
            ["current.example": true]
        )
        XCTAssertEqual(
            wallets?.first(where: { $0.id == requestedWallet.id })?.notificationSettings.dapps,
            ["existing.example": true, "new.example": false]
        )
    }
}

private extension WalletNotificationStoreTests {
    func makeWallet(id: String, dapps: [String: Bool]) -> Wallet {
        let publicKey = PublicKey(data: Data(repeating: 0x01, count: 32))
        return Wallet(
            id: id,
            identity: WalletIdentity(network: .mainnet, kind: .Regular(publicKey, .v5R1)),
            metaData: WalletMetaData(
                label: id,
                tintColor: .defaultColor,
                icon: .icon(.wallet)
            ),
            setupSettings: WalletSetupSettings(isSetupFinished: true),
            notificationSettings: NotificationSettings(isOn: true, dapps: dapps),
            batterySettings: BatterySettings()
        )
    }

    func makeKeeperInfo(wallets: [Wallet], currentWallet: Wallet) -> KeeperInfo {
        KeeperInfo(
            wallets: wallets,
            currentWallet: currentWallet,
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

private final class WalletNotificationKeeperInfoRepository: KeeperInfoRepository {
    private var info: KeeperInfo?

    init(info: KeeperInfo?) {
        self.info = info
    }

    func getKeeperInfo() throws -> KeeperInfo {
        guard let info else {
            throw WalletNotificationKeeperInfoRepositoryError.missing
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

private enum WalletNotificationKeeperInfoRepositoryError: Error {
    case missing
}

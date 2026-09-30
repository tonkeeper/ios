import Foundation
import KeeperCore
import KeeperCoreSensitive
import TKLogging
import UIKit
import UserNotifications

@MainActor
final class WalletBalanceSetupModel {
    struct State {
        enum Item: Equatable {
            case notifications
            case backup
            case migration(walletsLeft: Int)
            case biometry

            var identifier: String {
                switch self {
                case .notifications: "notifications"
                case .backup: "backup"
                case .migration: "migration"
                case .biometry: "biometry"
                }
            }
        }

        let wallet: Wallet
        let isFinishEnable: Bool
        let items: [Item]
    }

    var didUpdateState: ((State?) -> Void)?

    private(set) var wallet: Wallet

    private let walletsStore: WalletsStore
    private let processedBalanceStore: ProcessedBalanceStore
    private let securityStore: SecurityStore
    private let walletNotificationStore: WalletNotificationStore
    private let mnemonicsAccess: MnemonicAccess
    private let configuration: Configuration
    private let pushAuthorizationModel: PushAuthorizationModel
    private var didBecomeActiveObserver: NSObjectProtocol?

    init(
        wallet: Wallet,
        walletsStore: WalletsStore,
        processedBalanceStore: ProcessedBalanceStore,
        securityStore: SecurityStore,
        walletNotificationStore: WalletNotificationStore,
        mnemonicsAccess: MnemonicAccess,
        configuration: Configuration,
        pushAuthorizationModel: PushAuthorizationModel
    ) {
        self.wallet = wallet
        self.walletsStore = walletsStore
        self.processedBalanceStore = processedBalanceStore
        self.securityStore = securityStore
        self.walletNotificationStore = walletNotificationStore
        self.mnemonicsAccess = mnemonicsAccess
        self.configuration = configuration
        self.pushAuthorizationModel = pushAuthorizationModel

        walletsStore.addObserver(self) { observer, event in
            Task { @MainActor in
                observer.didGetWalletsStoreEvent(event)
            }
        }

        securityStore.addObserver(self) { observer, event in
            Task { @MainActor in
                switch event {
                case .didUpdateIsBiometryEnabled:
                    observer.notifyState()
                default:
                    break
                }
            }
        }

        walletNotificationStore.addObserver(self) { observer, event in
            Task { @MainActor in
                switch event {
                case .didUpdateNotificationsIsOn:
                    observer.notifyState()
                default:
                    break
                }
            }
        }

        processedBalanceStore.addObserver(self) { observer, event in
            Task { @MainActor in
                switch event {
                case let .didUpdateProccessedBalance(wallet):
                    guard observer.wallet == wallet else { return }
                    observer.notifyState()
                }
            }
        }

        pushAuthorizationModel.addObserver(self) { observer in
            observer.notifyState()
        }

        didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.notifyState()
            }
        }
    }

    deinit {
        didBecomeActiveObserver.map(NotificationCenter.default.removeObserver)
    }

    func getState() -> State? {
        calculateState(
            isSetupFinished: wallet.setupSettings.isSetupFinished,
            isBiometryEnable: securityStore.getState().isBiometryEnable,
            isNotificationsOn: walletNotificationStore.getState()[wallet]?.isOn ?? false,
            isPushAuthorizationGranted: pushAuthorizationModel.isGranted
        )
    }

    func finishSetup() {
        Task {
            guard let wallet = walletsStore.wallets.first(where: { $0.id == wallet.id }) else {
                return
            }
            await walletsStore.setWalletIsSetupFinished(wallet: wallet, isSetupFinished: true)
        }
    }

    func turnOnBiometry(passcode: String) async throws {
        try mnemonicsAccess.setPasscode(passcode)
        await securityStore.setIsBiometryEnable(true)
    }

    func turnOffBiometry() async throws {
        do {
            try mnemonicsAccess.deletePasscode()
        } catch {
            Log.e("failed to turn off biometry due to: \(error)")
            await securityStore.setIsBiometryEnable(false)
            throw error
        }
        await securityStore.setIsBiometryEnable(false)
    }

    func turnOnNotifications() async {
        let current = UNUserNotificationCenter.current()
        let settings = await current.notificationSettings()

        switch settings.authorizationStatus {
        case .denied:
            guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else { return }
            if UIApplication.shared.canOpenURL(settingsUrl) {
                UIApplication.shared.open(settingsUrl, options: [:], completionHandler: nil)
            }
            return
        case .notDetermined:
            guard await requestPushAuthorization() else { return }
        case .authorized, .provisional, .ephemeral:
            break
        @unknown default:
            guard await requestPushAuthorization() else { return }
        }

        await walletNotificationStore.setNotificationIsOn(true, wallet: wallet)
    }

    private func requestPushAuthorization() async -> Bool {
        do {
            guard try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            else {
                return false
            }
        } catch {
            Log.w("failed to request notification authorization: \(error)")
            return false
        }
        UIApplication.shared.registerForRemoteNotifications()
        return true
    }

    private func didGetWalletsStoreEvent(_ event: WalletsStore.Event) {
        switch event {
        case let .didUpdateWalletSetupSettings(wallet),
             let .didUpdateWalletMetaData(wallet),
             let .didUpdateWalletMultichain(wallet):
            guard self.wallet == wallet else { return }
            self.wallet = wallet
            notifyState()
        case .didAddWallets, .didDeleteWallet:
            notifyState()
        default:
            break
        }
    }

    private func notifyState() {
        didUpdateState?(getState())
    }

    private func calculateState(
        isSetupFinished: Bool,
        isBiometryEnable: Bool,
        isNotificationsOn: Bool,
        isPushAuthorizationGranted: Bool
    ) -> State? {
        let isBackupRequired = wallet.isBackupAvailable && !wallet.hasBackup
        if isSetupFinished, !isBackupRequired {
            return nil
        }

        let isBalanceFunded = isBalanceFunded(wallet: wallet)
        if isSetupFinished, !isBalanceFunded {
            return nil
        }

        var items = [State.Item]()

        let isFinishEnable = !isBackupRequired || !isBalanceFunded

        if isBackupRequired {
            items.append(.backup)
        }

        if !isSetupFinished, let walletsLeft = migrationWalletsLeft(for: wallet) {
            items.append(.migration(walletsLeft: walletsLeft))
        }

        var isBiometryStepDeferred = false
        if !isSetupFinished {
            if !isNotificationsOn, !isPushAuthorizationGranted {
                items.append(.notifications)
            }

            if wallet.isBiometryAvailable, !isBiometryEnable {
                if BiometryProvider().isAvailable {
                    items.append(.biometry)
                } else {
                    isBiometryStepDeferred = true
                }
            }
        }

        guard !items.isEmpty else {
            if !isSetupFinished, !isBiometryStepDeferred {
                finishSetup()
            }
            return nil
        }

        return State(
            wallet: wallet,
            isFinishEnable: isFinishEnable,
            items: items
        )
    }

    private func migrationWalletsLeft(for wallet: Wallet) -> Int? {
        guard wallet.isMultichain else {
            return nil
        }
        let walletsLeft = WalletMigrationVisibility.legacyTonWalletCount(wallets: walletsStore.wallets)
        return walletsLeft > 0 ? walletsLeft : nil
    }

    private func isBalanceFunded(wallet: Wallet) -> Bool {
        guard let processedBalance = processedBalanceStore.getState()[wallet]?.balance else {
            return false
        }
        return processedBalance.items.contains(where: { !$0.isZeroBalance })
    }
}

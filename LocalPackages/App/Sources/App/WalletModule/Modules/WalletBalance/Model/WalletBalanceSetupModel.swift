import Foundation
import KeeperCore
import KeeperCoreSensitive
import TKLogging
import UIKit
import UserNotifications

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

    private let syncQueue = DispatchQueue(label: "WalletBalanceSetupModelQueue")

    /// Written only on `syncQueue`; atomic because `getState()` is read from the caller's thread.
    @Atomic private var isPushAuthorizationGranted = false
    private var pushAuthorizationGeneration = 0
    private var didBecomeActiveObserver: NSObjectProtocol?

    var didUpdateState: ((State?) -> Void)?

    private let walletsStore: WalletsStore
    private let processedBalanceStore: ProcessedBalanceStore
    private let securityStore: SecurityStore
    private let walletNotificationStore: WalletNotificationStore
    private let mnemonicsAccess: MnemonicAccess
    private let configuration: Configuration

    init(
        walletsStore: WalletsStore,
        processedBalanceStore: ProcessedBalanceStore,
        securityStore: SecurityStore,
        walletNotificationStore: WalletNotificationStore,
        mnemonicsAccess: MnemonicAccess,
        configuration: Configuration
    ) {
        self.walletsStore = walletsStore
        self.processedBalanceStore = processedBalanceStore
        self.securityStore = securityStore
        self.walletNotificationStore = walletNotificationStore
        self.mnemonicsAccess = mnemonicsAccess
        self.configuration = configuration

        walletsStore.addObserver(self) { observer, event in
            observer.didGetWalletsStoreEvent(event)
        }

        securityStore.addObserver(self) { observer, event in
            observer.didGetSecurityStoreEvent(event)
        }

        walletNotificationStore.addObserver(self) { observer, event in
            observer.didGetWalletNotificationStoreEvent(event)
        }

        processedBalanceStore.addObserver(self) { observer, event in
            observer.didGetProcessedBalanceStoreEvent(event)
        }

        // `didBecomeActive`, not `willEnterForeground`: the system permission prompt only makes the
        // app inactive, so a grant given while this screen is alive posts no foreground transition.
        didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.refreshPushAuthorization()
        }
        refreshPushAuthorization()
    }

    deinit {
        didBecomeActiveObserver.map(NotificationCenter.default.removeObserver)
    }

    func getState() -> State? {
        guard let wallet = try? walletsStore.activeWallet else {
            return nil
        }
        let isSetupFinished = wallet.setupSettings.isSetupFinished
        let isBiometryEnable = securityStore.getState().isBiometryEnable
        let isNotificationsOn = walletNotificationStore.getState()[wallet]?.isOn ?? false
        return calculateState(
            wallet: wallet,
            isSetupFinished: isSetupFinished,
            isBiometryEnable: isBiometryEnable,
            isNotificationsOn: isNotificationsOn,
            isPushAuthorizationGranted: isPushAuthorizationGranted
        )
    }

    func finishSetup(for wallet: Wallet) {
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
            await self.securityStore.setIsBiometryEnable(false)
            throw error
        }
        await self.securityStore.setIsBiometryEnable(false)
    }

    func turnOnNotifications() async {
        guard let wallet = try? walletsStore.activeWallet else { return }
        let current = UNUserNotificationCenter.current()
        let settings = await current.notificationSettings()

        switch settings.authorizationStatus {
        case .denied:
            guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else { return }
            if await UIApplication.shared.canOpenURL(settingsUrl) {
                await MainActor.run {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            return
        case .notDetermined:
            guard await requestPushAuthorization() else { return }
        case .authorized, .provisional, .ephemeral:
            break
        @unknown default:
            guard await requestPushAuthorization() else { return }
        }

        await self.walletNotificationStore.setNotificationIsOn(true, wallet: wallet)
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
        await UIApplication.shared.registerForRemoteNotifications()
        return true
    }

    private func refreshPushAuthorization() {
        syncQueue.async { [weak self] in
            guard let self else { return }
            self.pushAuthorizationGeneration += 1
            let generation = self.pushAuthorizationGeneration
            Task { [weak self] in
                let isGranted = await UNUserNotificationCenter.current()
                    .notificationSettings().authorizationStatus.isPushAuthorized
                self?.applyPushAuthorization(isGranted, generation: generation)
            }
        }
    }

    private func applyPushAuthorization(_ isGranted: Bool, generation: Int) {
        syncQueue.async {
            guard generation == self.pushAuthorizationGeneration,
                  self.isPushAuthorizationGranted != isGranted
            else {
                return
            }
            self.isPushAuthorizationGranted = isGranted
            self.updateState()
        }
    }

    private func didGetWalletsStoreEvent(_ event: WalletsStore.Event) {
        syncQueue.async {
            switch event {
            case .didChangeActiveWallet:
                self.updateState()
            case .didUpdateWalletSetupSettings:
                self.updateState()
            case .didAddWallets, .didDeleteWallet:
                self.updateState()
            case let .didUpdateWalletMultichain(wallet):
                guard let activeWallet = try? self.walletsStore.activeWallet,
                      activeWallet == wallet
                else {
                    return
                }
                self.updateState()
            default: break
            }
        }
    }

    private func didGetSecurityStoreEvent(_ event: SecurityStore.Event) {
        syncQueue.async {
            switch event {
            case .didUpdateIsBiometryEnabled:
                self.updateState()
            default: break
            }
        }
    }

    private func didGetWalletNotificationStoreEvent(_ event: WalletNotificationStore.Event) {
        syncQueue.async {
            switch event {
            case .didUpdateNotificationsIsOn:
                self.updateState()
            default: break
            }
        }
    }

    private func didGetProcessedBalanceStoreEvent(_ event: ProcessedBalanceStore.Event) {
        syncQueue.async {
            switch event {
            case let .didUpdateProccessedBalance(wallet):
                guard let activeWallet = try? self.walletsStore.activeWallet,
                      activeWallet == wallet
                else {
                    return
                }
                self.updateState()
            }
        }
    }

    private func updateState() {
        let walletsStoreState = walletsStore.getState()
        switch walletsStoreState {
        case .empty: break
        case let .wallets(walletsState):
            let isBiometryEnable = securityStore.getState().isBiometryEnable
            let isSetupFinished = walletsState.activeWallet.setupSettings.isSetupFinished
            let isNotificationsOn = walletNotificationStore.getState()[walletsState.activeWallet]?.isOn ?? false
            let state = calculateState(
                wallet: walletsState.activeWallet,
                isSetupFinished: isSetupFinished,
                isBiometryEnable: isBiometryEnable,
                isNotificationsOn: isNotificationsOn,
                isPushAuthorizationGranted: isPushAuthorizationGranted
            )
            didUpdateState?(state)
        }
    }

    private func calculateState(
        wallet: Wallet,
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

        if !isSetupFinished {
            // The step exists to ask for push permission; once it is granted the wallet is
            // subscribed by default and turning it back off belongs to Settings.
            if !isNotificationsOn, !isPushAuthorizationGranted {
                items.append(.notifications)
            }

            if wallet.isBiometryAvailable, !isBiometryEnable {
                items.append(.biometry)
            }
        }

        guard !items.isEmpty else {
            if !isSetupFinished {
                finishSetup(for: wallet)
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
        guard configuration.featureEnabled(.multichainEnabled),
              configuration.featureEnabled(.migrationEnabled),
              wallet.isMultichain
        else {
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

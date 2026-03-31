import Foundation
import KeeperCore
import TKFeatureFlags
import UIKit
import UserNotifications

final class WalletBalanceSetupModel {
    struct State {
        enum Item: String {
            case notifications
            case backup
            case biometry
        }

        let wallet: Wallet
        let isFinishEnable: Bool
        let items: [Item]
    }

    private let syncQueue = DispatchQueue(label: "WalletBalanceSetupModelQueue")

    var didUpdateState: ((State?) -> Void)?

    private let walletsStore: WalletsStore
    private let securityStore: SecurityStore
    private let walletNotificationStore: WalletNotificationStore
    private let mnemonicsRepository: MnemonicsRepository
    private let configuration: Configuration

    init(
        walletsStore: WalletsStore,
        securityStore: SecurityStore,
        walletNotificationStore: WalletNotificationStore,
        mnemonicsRepository: MnemonicsRepository,
        configuration: Configuration
    ) {
        self.walletsStore = walletsStore
        self.securityStore = securityStore
        self.walletNotificationStore = walletNotificationStore
        self.mnemonicsRepository = mnemonicsRepository
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

        configuration.addUpdateObserver(self) { observer in
            observer.syncQueue.async { [weak observer] in
                observer?.updateState()
            }
        }
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
            isNotificationsOn: isNotificationsOn
        )
    }

    func finishSetup() {
        Task {
            guard let wallet = try? walletsStore.activeWallet else {
                return
            }
            await walletsStore.setWalletIsSetupFinished(wallet: wallet, isSetupFinished: true)
        }
    }

    func turnOnBiometry(passcode: String) throws {
        Task {
            try mnemonicsRepository.savePassword(passcode)
            await self.securityStore.setIsBiometryEnable(true)
        }
    }

    func turnOffBiometry() throws {
        Task {
            try self.mnemonicsRepository.deletePassword()
            await self.securityStore.setIsBiometryEnable(false)
        }
    }

    func turnOnNotifications() async {
        guard let wallet = try? walletsStore.activeWallet else { return }
        let current = UNUserNotificationCenter.current()

        let settings = await current.notificationSettings()
        if settings.authorizationStatus == .denied {
            guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else { return }

            if await UIApplication.shared.canOpenURL(settingsUrl) {
                DispatchQueue.main.async {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            return
        }
        await self.walletNotificationStore.setNotificationIsOn(true, wallet: wallet)
    }

    private func didGetWalletsStoreEvent(_ event: WalletsStore.Event) {
        syncQueue.async {
            switch event {
            case .didChangeActiveWallet:
                self.updateState()
            case .didUpdateWalletSetupSettings:
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
                isNotificationsOn: isNotificationsOn
            )
            didUpdateState?(state)
        }
    }

    private func calculateState(
        wallet: Wallet,
        isSetupFinished: Bool,
        isBiometryEnable: Bool,
        isNotificationsOn: Bool
    ) -> State? {
        if isSetupFinished, !wallet.isBackupAvailable || wallet.hasBackup {
            return nil
        }

        var items = [State.Item]()

        let isFinishEnable: Bool = !wallet.isBackupAvailable || wallet.setupSettings.backupDate != nil

        let isBackupVisible: Bool = wallet.isBackupAvailable && wallet.setupSettings.backupDate == nil
        if isBackupVisible {
            items.append(.backup)
        }

        if !isNotificationsOn {
            items.append(.notifications)
        }

        let isBiometryVisible: Bool = !isSetupFinished && wallet.isBiometryAvailable && !isBiometryEnable
        if isBiometryVisible {
            items.append(.biometry)
        }

        return State(
            wallet: wallet,
            isFinishEnable: isFinishEnable,
            items: items
        )
    }
}

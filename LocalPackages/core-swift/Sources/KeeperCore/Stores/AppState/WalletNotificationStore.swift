import Foundation
import TonSwift

public final class WalletNotificationStore: Store<WalletNotificationStore.Event, WalletNotificationStore.State> {
    public struct NotificationsState {
        public let isOn: Bool
        public let dapps: [String: Bool]
    }

    public typealias State = [Wallet: NotificationsState]
    public enum Event {
        case didUpdateNotificationsIsOn(wallet: Wallet)
        case didUpdateDappNotificationsIsOn(
            wallet: Wallet,
            dappHost: String,
            isOn: Bool
        )
    }

    private let keeperInfoStore: KeeperInfoStore

    init(keeperInfoStore: KeeperInfoStore) {
        self.keeperInfoStore = keeperInfoStore
        super.init(state: [:])
    }

    override public func createInitialState() -> State {
        getState(keeperInfo: keeperInfoStore.getState())
    }

    @discardableResult
    public func setNotificationIsOn(
        _ isOn: Bool,
        wallet: Wallet
    ) async -> State {
        return await withCheckedContinuation { continuation in
            setNotificationIsOn(isOn, wallet: wallet) { state in
                continuation.resume(returning: state)
            }
        }
    }

    @discardableResult
    public func setNotificationsIsOn(
        _ isOn: Bool,
        wallet: Wallet,
        dappHost: String
    ) async -> State {
        return await withCheckedContinuation { continuation in
            setNotificationsIsOn(isOn, wallet: wallet, dappHost: dappHost) { state in
                continuation.resume(returning: state)
            }
        }
    }

    public func setNotificationIsOn(
        _ isOn: Bool,
        wallet: Wallet,
        completion: ((State) -> Void)?
    ) {
        keeperInfoStore.updateKeeperInfo { keeperInfo in
            keeperInfo?.updateWallet(wallet, notificationsIsOn: isOn)
        } completion: { [weak self] keeperInfo in
            guard let self else { return }
            let state = self.getState(keeperInfo: keeperInfo)
            updateState { _ in
                StateUpdate(newState: state)
            } completion: { [weak self] state in
                self?.sendEvent(.didUpdateNotificationsIsOn(wallet: wallet))
                completion?(state)
            }
        }
    }

    public func setNotificationsIsOn(
        _ isOn: Bool,
        wallet: Wallet,
        dappHost: String,
        completion: ((State) -> Void)?
    ) {
        keeperInfoStore.updateKeeperInfo { keeperInfo in
            var updatedDappsNotifications = keeperInfo?.currentWallet.notificationSettings.dapps ?? [:]
            updatedDappsNotifications[dappHost] = isOn
            return keeperInfo?.updateWallet(
                wallet,
                dappsNotifications: updatedDappsNotifications
            )
        } completion: { [weak self] keeperInfo in
            guard let self else { return }
            let state = self.getState(keeperInfo: keeperInfo)
            updateState { _ in
                StateUpdate(newState: state)
            } completion: { [weak self] state in
                self?.sendEvent(
                    .didUpdateDappNotificationsIsOn(
                        wallet: wallet,
                        dappHost: dappHost,
                        isOn: isOn
                    )
                )
                completion?(state)
            }
        }
    }

    private func getState(keeperInfo: KeeperInfo?) -> State {
        guard let keeperInfo = keeperInfoStore.getState() else {
            return [:]
        }
        var result = State()
        for wallet in keeperInfo.wallets {
            let settings = wallet.notificationSettings
            result[wallet] = NotificationsState(
                isOn: settings.isOn,
                dapps: settings.dapps
            )
        }
        return result
    }
}

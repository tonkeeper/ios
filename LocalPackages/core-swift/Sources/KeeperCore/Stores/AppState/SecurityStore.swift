import Foundation

public final class SecurityStore: Store<SecurityStore.Event, SecurityStore.State> {
    public struct State {
        public let isBiometryEnable: Bool
        public let isLockScreen: Bool

        static var defaultState: State {
            State(isBiometryEnable: false, isLockScreen: false)
        }

        static func state(keeperInfo: KeeperInfo?) -> State {
            guard let keeperInfo else {
                return .defaultState
            }
            return State(
                isBiometryEnable: keeperInfo.securitySettings.isBiometryEnabled,
                isLockScreen: keeperInfo.securitySettings.isLockScreen
            )
        }
    }

    public enum Event {
        case didUpdateIsBiometryEnabled(isBiometryEnable: Bool)
        case didUpdateIsLockScreen(isLockScreen: Bool)
    }

    private let keeperInfoStore: KeeperInfoStore

    init(keeperInfoStore: KeeperInfoStore) {
        self.keeperInfoStore = keeperInfoStore
        super.init(state: .defaultState)
    }

    override public func createInitialState() -> State {
        State.state(keeperInfo: keeperInfoStore.getState())
    }

    @discardableResult
    public func setIsBiometryEnable(_ isBiometryEnable: Bool) async -> State {
        return await withCheckedContinuation { continuation in
            setIsBiometryEnable(isBiometryEnable) { state in
                continuation.resume(returning: state)
            }
        }
    }

    @discardableResult
    public func setIsLockScreen(_ isLockScreen: Bool) async -> State {
        return await withCheckedContinuation { continuation in
            setIsLockScreen(isLockScreen) { state in
                continuation.resume(returning: state)
            }
        }
    }

    public func setIsBiometryEnable(
        _ isBiometryEnable: Bool,
        completion: @escaping (State) -> Void
    ) {
        keeperInfoStore.updateKeeperInfo { keeperInfo in
            keeperInfo?.updateIsBiometryEnable(isBiometryEnable)
        } completion: { [weak self] keeperInfo in
            guard let self else { return }
            let state = State.state(keeperInfo: keeperInfo)
            updateState { _ in
                StateUpdate(newState: state)
            } completion: { [weak self] state in
                self?.sendEvent(.didUpdateIsBiometryEnabled(isBiometryEnable: isBiometryEnable))
                completion(state)
            }
        }
    }

    public func setIsLockScreen(
        _ isLockScreen: Bool,
        completion: @escaping (State) -> Void
    ) {
        keeperInfoStore.updateKeeperInfo { keeperInfo in
            keeperInfo?.updateIsLockScreen(isLockScreen)
        } completion: { [weak self] keeperInfo in
            guard let self else { return }
            let state = State.state(keeperInfo: keeperInfo)
            updateState { _ in
                StateUpdate(newState: state)
            } completion: { [weak self] state in
                self?.sendEvent(.didUpdateIsLockScreen(isLockScreen: isLockScreen))
                completion(state)
            }
        }
    }
}

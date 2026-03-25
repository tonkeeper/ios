import Foundation

public final class WalletsStore: Store<WalletsStore.Event, WalletsStore.State> {
    public enum Error: Swift.Error {
        case noWallets
    }

    public enum Event {
        case didAddWallets(wallets: [Wallet])
        case didChangeActiveWallet(from: Wallet, to: Wallet)
        case didMoveWallet(fromIndex: Int, toIndex: Int)
        case didUpdateWalletMetaData(wallet: Wallet)
        case didUpdateWalletSetupSettings(wallet: Wallet)
        case didDeleteWallet(wallet: Wallet)
        case didDeleteAll
        case didUpdateWalletBatterySettings(wallet: Wallet)
        case didUpdateWalletTron(wallet: Wallet)
    }

    public enum State {
        public struct Wallets {
            public let wallets: [Wallet]
            public let activeWallet: Wallet
        }

        case empty
        case wallets(Wallets)

        public var wallets: [Wallet] {
            switch self {
            case .empty:
                return []
            case let .wallets(wallets):
                return wallets.wallets
            }
        }

        public var activeWallet: Wallet {
            get throws {
                switch self {
                case .empty: throw Error.noWallets
                case let .wallets(state): return state.activeWallet
                }
            }
        }
    }

    public var wallets: [Wallet] {
        state.wallets
    }

    public var activeWallet: Wallet {
        get throws {
            try state.activeWallet
        }
    }

    private let keeperInfoStore: KeeperInfoStore

    override public func createInitialState() -> State {
        getState(keeperInfo: keeperInfoStore.getState())
    }

    init(keeperInfoStore: KeeperInfoStore) {
        self.keeperInfoStore = keeperInfoStore
        super.init(state: State.empty)
    }

    public func getWallet(id: String) -> Wallet? {
        wallets.first(where: { $0.id == id })
    }

    @discardableResult
    public func addWallets(_ wallets: [Wallet]) async -> State {
        return await withCheckedContinuation { continuation in
            addWallets(wallets) { state in
                continuation.resume(returning: state)
            }
        }
    }

    @discardableResult
    public func makeWalletActive(_ wallet: Wallet) async -> State {
        return await withCheckedContinuation { continuation in
            makeWalletActive(wallet) { state in
                continuation.resume(returning: state)
            }
        }
    }

    @discardableResult
    public func updateWalletMetaData(
        _ wallet: Wallet,
        metaData: WalletMetaData
    ) async -> State {
        return await withCheckedContinuation { continuation in
            updateWalletMetaData(wallet, metaData: metaData) { state in
                continuation.resume(returning: state)
            }
        }
    }

    @discardableResult
    public func deleteWallet(_ wallet: Wallet) async -> State {
        return await withCheckedContinuation { continuation in
            deleteWallet(wallet) { state in
                continuation.resume(returning: state)
            }
        }
    }

    @discardableResult
    public func deleteAllWallets() async -> State {
        return await withCheckedContinuation { continuation in
            deleteAllWallets { state in
                continuation.resume(returning: state)
            }
        }
    }

    @discardableResult
    public func moveWallet(fromIndex: Int, toIndex: Int) async -> State {
        return await withCheckedContinuation { continuation in
            moveWallet(fromIndex: fromIndex, toIndex: toIndex) { state in
                continuation.resume(returning: state)
            }
        }
    }

    @discardableResult
    public func setWalletBackupDate(
        wallet: Wallet,
        backupDate: Date?
    ) async -> State {
        return await withCheckedContinuation { continuation in
            setWalletBackupDate(
                wallet: wallet,
                backupDate: backupDate
            ) { state in
                continuation.resume(returning: state)
            }
        }
    }

    @discardableResult
    public func setWalletIsSetupFinished(
        wallet: Wallet,
        isSetupFinished: Bool
    ) async -> State {
        return await withCheckedContinuation { continuation in
            setWalletIsSetupFinished(
                wallet: wallet,
                isSetupFinished: isSetupFinished
            ) { state in
                continuation.resume(returning: state)
            }
        }
    }

    @discardableResult
    public func setWalletTron(
        wallet: Wallet,
        tron: WalletTron?
    ) async -> State {
        return await withCheckedContinuation { continuation in
            setWalletTron(wallet: wallet, tron: tron) { state in
                continuation.resume(returning: state)
            }
        }
    }

    public func addWallets(
        _ wallets: [Wallet],
        completion: @escaping (State) -> Void
    ) {
        guard !wallets.isEmpty else { return }

        let prevWallet = try? activeWallet
        let activeWallet = wallets[0]
        keeperInfoStore.updateKeeperInfo { keeperInfo in
            guard let keeperInfo else {
                return KeeperInfo.keeperInfo(wallets: wallets)
            }
            let filter: (Wallet) -> Bool = { wallet in
                !wallets.contains(where: { $0.isIdentityEqual(wallet: wallet) })
            }
            let wallets = keeperInfo.wallets.filter(filter) + wallets
            return keeperInfo.updateWallets(
                wallets,
                activeWallet: activeWallet
            )
        } completion: { [weak self] keeperInfo in
            guard let self else { return }
            let state = self.getState(keeperInfo: keeperInfo)
            updateState { _ in
                StateUpdate(newState: state)
            } completion: { [weak self] state in
                self?.sendEvent(.didAddWallets(wallets: wallets))
                self?.sendEvent(.didChangeActiveWallet(from: prevWallet ?? activeWallet, to: activeWallet))
                completion(state)
            }
        }
    }

    public func makeWalletActive(
        _ wallet: Wallet,
        completion: @escaping (State) -> Void
    ) {
        let activeWallet = try? activeWallet

        keeperInfoStore.updateKeeperInfo { keeperInfo in
            guard let keeperInfo else { return nil }
            return keeperInfo.updateActiveWallet(wallet)
        } completion: { [weak self] keeperInfo in
            guard let self else { return }
            let state = self.getState(keeperInfo: keeperInfo)
            updateState { _ in
                StateUpdate(newState: state)
            } completion: { [weak self] state in
                self?.sendEvent(.didChangeActiveWallet(from: activeWallet ?? wallet, to: wallet))
                completion(state)
            }
        }
    }

    public func updateWalletMetaData(
        _ wallet: Wallet,
        metaData: WalletMetaData,
        completion: @escaping (State) -> Void
    ) {
        keeperInfoStore.updateKeeperInfo { keeperInfo in
            guard let keeperInfo else { return nil }
            return keeperInfo.updateWallet(wallet, metaData: metaData).keeperInfo
        } completion: { [weak self] keeperInfo in
            guard let self else { return }
            let state = self.getState(keeperInfo: keeperInfo)
            updateState { _ in
                StateUpdate(newState: state)
            } completion: { [weak self] state in
                guard let wallet = state.wallets.first(where: { $0 == wallet }) else { return }
                self?.sendEvent(.didUpdateWalletMetaData(wallet: wallet))
                completion(state)
            }
        }
    }

    public func deleteWallet(
        _ wallet: Wallet,
        completion: @escaping (State) -> Void
    ) {
        keeperInfoStore.updateKeeperInfo { keeperInfo in
            guard let keeperInfo else { return nil }
            return keeperInfo.deleteWallet(wallet)
        } completion: { [weak self] keeperInfo in
            guard let self else { return }
            let state = self.getState(keeperInfo: keeperInfo)
            updateState { _ in
                StateUpdate(newState: state)
            } completion: { [weak self] state in
                switch state {
                case .empty:
                    self?.sendEvent(.didDeleteAll)
                case let .wallets(walletsState):
                    self?.sendEvent(.didDeleteWallet(wallet: wallet))
                    self?.sendEvent(.didChangeActiveWallet(from: wallet, to: walletsState.activeWallet))
                }
                completion(state)
            }
        }
    }

    public func deleteAllWallets(completion: @escaping (State) -> Void) {
        keeperInfoStore.updateKeeperInfo { _ in
            nil
        } completion: { [weak self] _ in
            guard let self else { return }
            updateState { _ in
                StateUpdate(newState: .empty)
            } completion: { [weak self] state in
                self?.sendEvent(.didDeleteAll)
                completion(state)
            }
        }
    }

    public func moveWallet(fromIndex: Int, toIndex: Int, completion: @escaping (State) -> Void) {
        keeperInfoStore.updateKeeperInfo { keeperInfo in
            guard let keeperInfo else { return nil }
            return keeperInfo.moveWallet(
                fromIndex: fromIndex,
                toIndex: toIndex
            )
        } completion: { [weak self] keeperInfo in
            guard let self else { return }
            let state = self.getState(keeperInfo: keeperInfo)
            updateState { _ in
                StateUpdate(newState: state)
            } completion: { [weak self] _ in
                self?.sendEvent(.didMoveWallet(fromIndex: fromIndex, toIndex: toIndex))
                completion(state)
            }
        }
    }

    public func setWalletBackupDate(
        wallet: Wallet,
        backupDate: Date?,
        completion: @escaping (State) -> Void
    ) {
        keeperInfoStore.updateKeeperInfo { keeperInfo in
            guard let keeperInfo else { return nil }
            return keeperInfo.updateWalletBackupDate(
                wallet,
                backupDate: backupDate
            )
        } completion: { [weak self] keeperInfo in
            guard let self else { return }
            let state = self.getState(keeperInfo: keeperInfo)
            updateState { _ in
                StateUpdate(newState: state)
            } completion: { [weak self] _ in
                self?.sendEvent(.didUpdateWalletSetupSettings(wallet: wallet))
                completion(state)
            }
        }
    }

    public func setWalletIsSetupFinished(
        wallet: Wallet,
        isSetupFinished: Bool,
        completion: @escaping (State) -> Void
    ) {
        keeperInfoStore.updateKeeperInfo { keeperInfo in
            guard let keeperInfo else { return nil }
            return keeperInfo.updateWalletIsSetupFinished(
                wallet,
                isSetupFinished: isSetupFinished
            )
        } completion: { [weak self] keeperInfo in
            guard let self else { return }
            let state = self.getState(keeperInfo: keeperInfo)
            updateState { _ in
                StateUpdate(newState: state)
            } completion: { [weak self] _ in
                self?.sendEvent(.didUpdateWalletSetupSettings(wallet: wallet))
                completion(state)
            }
        }
    }

    public func setWalletBatterySettings(
        wallet: Wallet,
        batterySettings: BatterySettings,
        completion: ((State) -> Void)?
    ) {
        keeperInfoStore.updateKeeperInfo { keeperInfo in
            guard let keeperInfo else { return nil }
            return keeperInfo.updateWallet(wallet, batterySettings: batterySettings).keeperInfo
        } completion: { [weak self] keeperInfo in
            guard let self else { return }
            let state = self.getState(keeperInfo: keeperInfo)
            updateState { _ in
                StateUpdate(newState: state)
            } completion: { [weak self] _ in
                self?.sendEvent(.didUpdateWalletBatterySettings(wallet: wallet))
                completion?(state)
            }
        }
    }

    public func setWalletTron(
        wallet: Wallet,
        tron: WalletTron?,
        completion: ((State) -> Void)?
    ) {
        keeperInfoStore.updateKeeperInfo { keeperInfo in
            guard let keeperInfo else { return nil }
            return keeperInfo.updateWallet(wallet, tron: tron).keeperInfo
        } completion: { [weak self] keeperInfo in
            guard let self else { return }
            let state = self.getState(keeperInfo: keeperInfo)
            updateState { _ in
                StateUpdate(newState: state)
            } completion: { [weak self] _ in
                guard let wallet = state.wallets.first(where: { $0 == wallet }) else { return }
                self?.sendEvent(.didUpdateWalletTron(wallet: wallet))
                completion?(state)
            }
        }
    }

    public func reload(completion: @escaping () -> Void) {
        updateState { [weak self] _ in
            guard let self else { return nil }
            let state = getState(keeperInfo: keeperInfoStore.state)
            return StateUpdate(newState: state)
        } completion: {
            _ in completion()
        }
    }

    private func getState(keeperInfo: KeeperInfo?) -> State {
        if let keeperInfo = keeperInfoStore.getState() {
            return .wallets(State.Wallets(wallets: keeperInfo.wallets, activeWallet: keeperInfo.currentWallet))
        } else {
            return .empty
        }
    }
}

private extension KeeperInfo {
    static func keeperInfo(wallets: [Wallet]) -> KeeperInfo {
        return KeeperInfo(
            wallets: wallets,
            currentWallet: wallets[0],
            currency: .defaultCurrency,
            securitySettings: SecuritySettings(isBiometryEnabled: false, isLockScreen: false),
            appSettings: AppSettings(isSecureMode: false, searchEngine: .duckduckgo),
            country: .auto,
            batterySettings: BatterySettings(),
            assetsPolicy: AssetsPolicy(policies: [:], ordered: []),
            appCollection: AppCollection(connected: [:], recent: [], pinned: [])
        )
    }
}

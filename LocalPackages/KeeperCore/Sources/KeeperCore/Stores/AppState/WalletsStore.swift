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
        case didUpdateWalletMultichain(wallet: Wallet)
    }

    public enum State {
        public struct Wallets {
            public let wallets: [Wallet]
            public let activeWallet: Wallet
            fileprivate let activeWalletSelectionID: UUID
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

    public struct ActiveWalletSelection: Equatable, Sendable {
        public let walletID: String
        public let selectionID: UUID
    }

    public var wallets: [Wallet] {
        state.wallets
    }

    public var activeWallet: Wallet {
        get throws {
            try state.activeWallet
        }
    }

    public var activeWalletSelection: ActiveWalletSelection {
        get throws {
            switch state {
            case .empty:
                throw Error.noWallets
            case let .wallets(state):
                return ActiveWalletSelection(
                    walletID: state.activeWallet.id,
                    selectionID: state.activeWalletSelectionID
                )
            }
        }
    }

    private let keeperInfoStore: KeeperInfoStore

    override public func createInitialState() -> State {
        getState(
            keeperInfo: keeperInfoStore.getState(),
            activeWalletSelectionID: UUID()
        )
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
        await withCheckedContinuation { continuation in
            setWalletTron(wallet: wallet, tron: tron) { state in
                continuation.resume(returning: state)
            }
        }
    }

    @discardableResult
    public func setWalletMultichain(
        wallet: Wallet,
        multichain: MultichainWallet?
    ) async -> State {
        return await withCheckedContinuation { continuation in
            setWalletMultichain(wallet: wallet, multichain: multichain) { state in
                continuation.resume(returning: state)
            }
        }
    }

    @discardableResult
    public func updateWalletMultichain(
        wallet: Wallet,
        transform: @escaping (Wallet) -> MultichainWallet?
    ) async -> State {
        return await withCheckedContinuation { continuation in
            updateWalletMultichain(wallet: wallet, transform: transform) { state in
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
            updateWalletsState(keeperInfo: keeperInfo, changesActiveWallet: true) { [weak self] state in
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
            updateWalletsState(keeperInfo: keeperInfo, changesActiveWallet: true) { [weak self] state in
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
            updateWalletsState(keeperInfo: keeperInfo) { [weak self] state in
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
            updateWalletsState(keeperInfo: keeperInfo, changesActiveWallet: true) { [weak self] state in
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
            updateWalletsState(keeperInfo: nil, changesActiveWallet: true) { [weak self] state in
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
            updateWalletsState(keeperInfo: keeperInfo) { [weak self] state in
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
            updateWalletsState(keeperInfo: keeperInfo) { [weak self] state in
                let updatedWallet = state.wallets.first(where: { $0.id == wallet.id }) ?? wallet
                self?.sendEvent(.didUpdateWalletSetupSettings(wallet: updatedWallet))
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
            updateWalletsState(keeperInfo: keeperInfo) { [weak self] state in
                let updatedWallet = state.wallets.first(where: { $0.id == wallet.id }) ?? wallet
                self?.sendEvent(.didUpdateWalletSetupSettings(wallet: updatedWallet))
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
            updateWalletsState(keeperInfo: keeperInfo) { [weak self] state in
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
            updateWalletsState(keeperInfo: keeperInfo) { state in
                completion?(state)
            }
        }
    }

    /// Multichain state has two independent writers — the addresses enricher and the wallet sync —
    /// so reading it before the update lets the other one's write land in the gap and be restored
    /// to its previous value. `transform` runs inside the store update against the stored wallet;
    /// returning `nil` leaves it untouched, and clearing the state stays `setWalletMultichain`'s job.
    public func updateWalletMultichain(
        wallet: Wallet,
        transform: @escaping (Wallet) -> MultichainWallet?,
        completion: ((State) -> Void)?
    ) {
        keeperInfoStore.updateKeeperInfo { keeperInfo in
            guard let keeperInfo else { return nil }
            guard let stored = keeperInfo.wallets.first(where: { $0.id == wallet.id }),
                  let multichain = transform(stored)
            else {
                return keeperInfo
            }
            return keeperInfo.updateWallet(stored, multichain: multichain).keeperInfo
        } completion: { [weak self] keeperInfo in
            guard let self else { return }
            updateWalletsState(keeperInfo: keeperInfo) { [weak self] state in
                if let wallet = state.wallets.first(where: { $0 == wallet }) {
                    self?.sendEvent(.didUpdateWalletMultichain(wallet: wallet))
                }
                completion?(state)
            }
        }
    }

    /// Applies `multichain` to the wallet already on disk, not the caller's snapshot. Enrichment
    /// and push auto-enable race on create: the enricher holds a pre-enable wallet and would
    /// otherwise rewrite `notificationSettings.isOn` back to false while attaching multichain.
    public func setWalletMultichain(
        wallet: Wallet,
        multichain: MultichainWallet?,
        completion: ((State) -> Void)?
    ) {
        keeperInfoStore.updateKeeperInfo { keeperInfo in
            guard let keeperInfo else { return nil }
            guard let stored = keeperInfo.wallets.first(where: { $0.id == wallet.id }) else {
                return keeperInfo
            }
            return keeperInfo.updateWallet(stored, multichain: multichain).keeperInfo
        } completion: { [weak self] keeperInfo in
            guard let self else { return }
            updateWalletsState(keeperInfo: keeperInfo) { [weak self] state in
                if let wallet = state.wallets.first(where: { $0 == wallet }) {
                    self?.sendEvent(.didUpdateWalletMultichain(wallet: wallet))
                }
                completion?(state)
            }
        }
    }

    public func reload(completion: @escaping () -> Void) {
        updateWalletsState(keeperInfo: keeperInfoStore.state) { _ in completion() }
    }

    private func updateWalletsState(
        keeperInfo: KeeperInfo?,
        changesActiveWallet: Bool = false,
        completion: @escaping (State) -> Void
    ) {
        updateState({ [weak self] state in
            guard let self else { return nil }
            let selectionID: UUID
            let newActiveWalletID = keeperInfo?.currentWallet.id
            let currentActiveWalletID = try? state.activeWallet.id
            if changesActiveWallet || currentActiveWalletID != newActiveWalletID {
                selectionID = UUID()
            } else if case let .wallets(wallets) = state {
                selectionID = wallets.activeWalletSelectionID
            } else {
                selectionID = UUID()
            }
            return StateUpdate(
                newState: getState(
                    keeperInfo: keeperInfo,
                    activeWalletSelectionID: selectionID
                )
            )
        }, completion: completion)
    }

    private func getState(
        keeperInfo: KeeperInfo?,
        activeWalletSelectionID: UUID
    ) -> State {
        if let keeperInfo {
            return .wallets(
                State.Wallets(
                    wallets: keeperInfo.wallets,
                    activeWallet: keeperInfo.currentWallet,
                    activeWalletSelectionID: activeWalletSelectionID
                )
            )
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

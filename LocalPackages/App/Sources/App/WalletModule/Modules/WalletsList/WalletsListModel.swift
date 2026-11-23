import Foundation
import KeeperCore

struct WalletsListModelState {
    let wallets: [Wallet]
    let selectedWalletIdentifier: String?
}

protocol WalletsListModel: AnyObject {
    var isEditable: Bool { get }
    var subtitle: String? { get }
    var didUpdateState: ((WalletsListModelState) -> Void)? { get set }

    func getState() -> WalletsListModelState
    func selectWallet(wallet: Wallet)
    func moveWallet(fromIndex: Int, toIndex: Int)
    func getWallet(id: String) -> Wallet?
}

extension WalletsListModel {
    var subtitle: String? {
        nil
    }
}

final class WalletsPickerListModel: WalletsListModel {
    private let walletsStore: WalletsStore

    init(walletsStore: WalletsStore) {
        self.walletsStore = walletsStore
        walletsStore.addObserver(self) { observer, event in
            DispatchQueue.main.async {
                switch event {
                case .didAddWallets,
                     .didDeleteWallet,
                     .didChangeActiveWallet,
                     .didMoveWallet,
                     .didUpdateWalletMetaData,
                     .didUpdateWalletMultichain:
                    observer.updateState()
                default: break
                }
            }
        }
    }

    var isEditable: Bool {
        true
    }

    var didUpdateState: ((WalletsListModelState) -> Void)?

    func getState() -> WalletsListModelState {
        let state = walletsStore.state
        guard let activeWallet = try? state.activeWallet else {
            return WalletsListModelState(
                wallets: [],
                selectedWalletIdentifier: nil
            )
        }

        return WalletsListModelState(
            wallets: state.wallets,
            selectedWalletIdentifier: activeWallet.id
        )
    }

    func selectWallet(wallet: Wallet) {
        Task {
            do {
                guard try walletsStore.activeWallet != wallet else { return }
                await walletsStore.makeWalletActive(wallet)
            } catch { return }
        }
    }

    func moveWallet(fromIndex: Int, toIndex: Int) {
        Task {
            await walletsStore.moveWallet(fromIndex: fromIndex, toIndex: toIndex)
        }
    }

    private func updateState() {
        let state = walletsStore.state
        guard let activeWallet = try? state.activeWallet else {
            return
        }
        didUpdateState?(
            WalletsListModelState(
                wallets: state.wallets,
                selectedWalletIdentifier: activeWallet.id
            )
        )
    }

    func getWallet(id: String) -> Wallet? {
        guard let wallet = walletsStore.getState().wallets.first(where: { $0.id == id }) else { return nil }
        return wallet
    }
}

final class MultichainWalletsPickerListModel: WalletsListModel {
    var didSelectWallet: ((Wallet) -> Void)?
    var didUpdateState: ((WalletsListModelState) -> Void)?
    let subtitle: String?

    private let walletsStore: WalletsStore
    private let isEligible: (Wallet) -> Bool

    init(walletsStore: WalletsStore, isEligible: @escaping (Wallet) -> Bool, subtitle: String?) {
        self.walletsStore = walletsStore
        self.isEligible = isEligible
        self.subtitle = subtitle
    }

    var isEditable: Bool {
        false
    }

    func getState() -> WalletsListModelState {
        WalletsListModelState(
            wallets: walletsStore.wallets.filter(isEligible),
            selectedWalletIdentifier: nil
        )
    }

    func selectWallet(wallet: Wallet) {
        didSelectWallet?(wallet)
    }

    func moveWallet(fromIndex: Int, toIndex: Int) {}

    func getWallet(id: String) -> Wallet? {
        walletsStore.wallets.first { $0.id == id }
    }
}

final class TonConnectWalletsPickerListModel: WalletsListModel {
    var didSelectWallet: ((Wallet) -> Void)?

    private let walletsStore: WalletsStore
    private let selectedWallet: Wallet

    init(
        walletsStore: WalletsStore,
        selectedWallet: Wallet
    ) {
        self.walletsStore = walletsStore
        self.selectedWallet = selectedWallet
    }

    var isEditable: Bool {
        false
    }

    var didUpdateState: ((WalletsListModelState) -> Void)?

    func getState() -> WalletsListModelState {
        let state = walletsStore.state
        guard let _ = try? state.activeWallet else {
            return WalletsListModelState(
                wallets: [],
                selectedWalletIdentifier: nil
            )
        }

        let wallets = state.wallets.filter { $0.isTonconnectAvailable }
        guard let activeWallet = (wallets.first(where: { $0 == selectedWallet }) ?? wallets.first) else {
            return WalletsListModelState(wallets: wallets, selectedWalletIdentifier: nil)
        }
        return WalletsListModelState(wallets: wallets, selectedWalletIdentifier: activeWallet.id)
    }

    func selectWallet(wallet: Wallet) {
        DispatchQueue.main.async {
            self.didSelectWallet?(wallet)
        }
    }

    func moveWallet(fromIndex: Int, toIndex: Int) {}

    func getWallet(id: String) -> Wallet? {
        let wallets = walletsStore.state.wallets.filter { $0.isTonconnectAvailable }
        guard let wallet = wallets.first(where: { $0.isTonconnectAvailable }) else {
            return nil
        }
        return wallet
    }
}

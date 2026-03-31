import Foundation
import KeeperCore
import TKLocalize
import TKUIKit
import TonSwift

@MainActor
protocol CollectiblesListModuleOutput: AnyObject {
    var didSelectNFT: ((NFT, _ wallet: Wallet) -> Void)? { get set }
}

@MainActor
protocol CollectiblesListViewModel: AnyObject {
    var didUpdateSnapshot: ((CollectiblesList.Snapshot) -> Void)? { get set }
    var didUpdateEmptyViewModel: ((TKEmptyViewController.Model) -> Void)? { get set }
    var didStopLoading: (() -> Void)? { get set }

    func viewDidLoad()
    func getNFTCellModel(identifier: String) -> CollectibleCollectionViewCell.Model?
    func didSelectNftAt(index: Int)
    func reload()
}

@MainActor
final class CollectiblesListViewModelImplementation: CollectiblesListViewModel, CollectiblesListModuleOutput {
    // MARK: - CollectiblesListModuleOutput

    var didSelectNFT: ((NFT, _ wallet: Wallet) -> Void)?

    // MARK: - CollectiblesListViewModel

    var didUpdateSnapshot: ((CollectiblesList.Snapshot) -> Void)?
    var didUpdateEmptyViewModel: ((TKEmptyViewController.Model) -> Void)?
    var didStopLoading: (() -> Void)?

    func viewDidLoad() {
        Task { await walletNFTsStore.addObserver(self) }

        appSettingsStore.addObserver(self) { observer, event in
            switch event {
            case .didUpdateIsSecureMode:
                observer.update()
            default: break
            }
        }

        updateEmptyView()
        update()
    }

    func getNFTCellModel(identifier: String) -> CollectibleCollectionViewCell.Model? {
        models[identifier]
    }

    func didSelectNftAt(index: Int) {
        guard let nft = nfts[safe: index] else {
            return
        }
        didSelectNFT?(nft, wallet)
    }

    func reload() {
        Task { await walletNFTsStore.loadNFTs() }
    }

    // MARK: - State

    private var models = [String: CollectibleCollectionViewCell.Model]()
    private var nfts = [NFT]()

    // MARK: - Mapper

    private lazy var collectiblesListMapper = CollectiblesListMapper(
        walletNftManagementStore: walletNftManagementStore
    )

    // MARK: - Dependencies

    private let wallet: Wallet
    private let walletNFTsStore: WalletNFTStore
    private let walletNftManagementStore: WalletNFTsManagementStore
    private let appSettingsStore: AppSettingsStore

    // MARK: - Init

    init(
        wallet: Wallet,
        walletNFTsStore: WalletNFTStore,
        walletNftManagementStore: WalletNFTsManagementStore,
        appSettingsStore: AppSettingsStore
    ) {
        self.wallet = wallet
        self.walletNFTsStore = walletNFTsStore
        self.walletNftManagementStore = walletNftManagementStore
        self.appSettingsStore = appSettingsStore
    }
}

private extension CollectiblesListViewModelImplementation {
    func update() {
        let nfts = walletNFTsStore.state.value.nfts.visible
        let isSecureMode = appSettingsStore.getState().isSecureMode
        update(nfts: nfts, isSecureMode: isSecureMode)
    }

    func update(nfts: [NFT], isSecureMode: Bool) {
        let snapshot = self.createSnapshot(state: nfts)
        let models = self.createModels(state: nfts, isSecureMode: isSecureMode)
        self.nfts = nfts
        self.models = models
        self.didUpdateSnapshot?(snapshot)
    }

    func updateEmptyView() {
        didUpdateEmptyViewModel?(TKEmptyViewController.Model(
            title: TKLocales.Purchases.emptyPlaceholder,
            caption: nil,
            buttons: []
        ))
    }

    func createSnapshot(state: [NFT]) -> CollectiblesList.Snapshot {
        var snapshot = CollectiblesList.Snapshot()
        if state.isEmpty {
            snapshot.appendSections([.empty])
            snapshot.appendItems([.empty], toSection: .empty)
        } else {
            snapshot.appendSections([.all])
            snapshot.appendItems(state.map { .nft(identifier: $0.address.toString()) }, toSection: .all)
        }

        if #available(iOS 15.0, *) {
            snapshot.reconfigureItems(snapshot.itemIdentifiers)
        } else {
            snapshot.reloadItems(snapshot.itemIdentifiers)
        }

        return snapshot
    }

    func createModels(state: [NFT], isSecureMode: Bool) -> [String: CollectibleCollectionViewCell.Model] {
        return state.reduce(into: [String: CollectibleCollectionViewCell.Model]()) { result, item in
            let model = collectiblesListMapper.map(nft: item, isSecureMode: isSecureMode)
            let identifier = item.address.toString()
            result[identifier] = model
        }
    }
}

extension CollectiblesListViewModelImplementation: WalletNFTStoreObserver {
    nonisolated func didUpdateNFTs(_ nfts: WalletNFTs) {
        Task { @MainActor in update() }
    }

    nonisolated func didUpdateLoadingState(_ loadingState: WalletNFTStore.LoadingState) {
        guard loadingState == .idle else { return }
        Task { @MainActor [weak self] in self?.didStopLoading?() }
    }
}

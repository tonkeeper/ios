import Combine
import Foundation
import KeeperCore
import TonSwift

@MainActor
protocol CollectiblesListModuleOutput: AnyObject {
    var didSelectNFT: ((NFT, _ wallet: Wallet) -> Void)? { get set }
    var didRequestOpenTonCollectiblesPopup: (() -> Void)? { get set }
    var didTapCollectiblesSettings: ((_ isSpam: Bool) -> Void)? { get set }
}

@MainActor
final class CollectiblesListViewModelImplementation: ObservableObject, CollectiblesListModuleOutput {
    struct RowData: Equatable {
        var nfts: WalletNFTs
        var items: [CollectiblesListItem]

        static var initial: RowData {
            RowData(
                nfts: .empty,
                items: []
            )
        }
    }

    enum State {
        case idle
        case refreshing(
            rowData: RowData
        )
        case loaded(
            rowData: RowData
        )
    }

    // MARK: - CollectiblesListModuleOutput

    var didSelectNFT: ((NFT, _ wallet: Wallet) -> Void)?
    var didRequestOpenTonCollectiblesPopup: (() -> Void)?
    var didTapCollectiblesSettings: ((_ isSpam: Bool) -> Void)?

    // MARK: - State

    let isMultichain: Bool
    @Published private(set) var state: State
    @Published private(set) var hasBackButton = false
    @Published private(set) var scrollToTopRequestID = UUID()

    private var onTapBack: (() -> Void)?
    private var loadTask: Task<Void, Never>?
    private var didLoad = false

    func viewDidLoad() {
        guard !didLoad else { return }
        didLoad = true

        Task { await walletNFTsStore.addObserver(self) }

        appSettingsStore.addObserver(self) { observer, event in
            switch event {
            case .didUpdateIsSecureMode:
                Task { @MainActor in
                    observer.update()
                }
            default: break
            }
        }

        loadIfNeeded()
    }

    func openTonCollectiblesPopup() {
        didRequestOpenTonCollectiblesPopup?()
    }

    func configureHeader(onTapBack: (() -> Void)?) {
        self.onTapBack = onTapBack
        hasBackButton = onTapBack != nil
    }

    func tapBack() {
        onTapBack?()
    }

    func tapSettings() {
        didTapCollectiblesSettings?(false)
    }

    func selectItem(id: String) {
        guard let nft = currentRowData?.nfts.visible.first(where: { $0.address.toRaw() == id }) else {
            return
        }
        didSelectNFT?(nft, wallet)
    }

    func refresh() async {
        let rowData: RowData
        switch state {
        case .refreshing:
            await loadTask?.value
            return
        case .idle:
            rowData = makeRowData(nfts: walletNFTsStore.state.value.nfts)
        case let .loaded(data):
            rowData = data
        }

        state = .refreshing(rowData: rowData)
        startLoadTask()
        await loadTask?.value
    }

    func requestScrollToTop() {
        scrollToTopRequestID = UUID()
    }

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
        self.state = .idle
        self.isMultichain = wallet.isMultichain
    }

    deinit {
        loadTask?.cancel()
    }
}

private extension CollectiblesListViewModelImplementation {
    var currentRowData: RowData? {
        switch state {
        case .idle:
            return nil
        case let .refreshing(rowData),
             let .loaded(rowData):
            return rowData
        }
    }

    func loadIfNeeded() {
        guard case .idle = state else { return }

        state = .refreshing(rowData: makeRowData(nfts: walletNFTsStore.state.value.nfts))
        startLoadTask()
    }

    func startLoadTask() {
        loadTask = Task { [weak self, walletNFTsStore] in
            let nfts = await walletNFTsStore.loadNFTs()
            guard !Task.isCancelled else {
                return
            }
            self?.finishLoading(nfts: nfts)
        }
    }

    func finishLoading(nfts: WalletNFTs) {
        state = .loaded(rowData: makeRowData(nfts: nfts))
        loadTask = nil
    }

    func update() {
        update(nfts: walletNFTsStore.state.value.nfts)
    }

    func update(nfts: WalletNFTs) {
        let rowData = makeRowData(nfts: nfts)

        switch state {
        case .idle:
            state = rowData == .initial
                ? .idle
                : .loaded(rowData: rowData)
        case .refreshing:
            state = .refreshing(rowData: rowData)
        case .loaded:
            state = .loaded(rowData: rowData)
        }
    }

    func makeRowData(nfts: WalletNFTs) -> RowData {
        let isSecureMode = appSettingsStore.getState().isSecureMode
        let items = nfts.visible.map {
            collectiblesListMapper.map(nft: $0, isSecureMode: isSecureMode)
        }
        return RowData(
            nfts: nfts,
            items: items
        )
    }
}

extension CollectiblesListViewModelImplementation: WalletNFTStoreObserver {
    nonisolated func didUpdateNFTs(_ nfts: WalletNFTs) {
        Task { @MainActor in
            update(nfts: nfts)
        }
    }
}

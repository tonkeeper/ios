import Foundation
import TonSwift

public protocol WalletNFTStoreObserver: AnyObject {
    func didUpdateNFTs(_ nfts: WalletNFTs)
    func didUpdateLoadingState(_ loadingState: WalletNFTStore.LoadingState)
}

public extension WalletNFTStoreObserver {
    func didUpdateNFTs(_ nfts: WalletNFTs) {}
    func didUpdateLoadingState(_ loadingState: WalletNFTStore.LoadingState) {}
}

private struct WeakWalletNFTStoreObserver {
    weak var observer: WalletNFTStoreObserver?
}

public actor WalletNFTStore {
    public struct State {
        public let loadingState: LoadingState
        public let nfts: WalletNFTs
    }

    public enum LoadingState {
        case idle
        case loading
    }

    public nonisolated let state: StoreState<State>

    private var _state: State {
        get { state.value }
        set {
            let oldValue = state.value
            state.value = newValue
            if oldValue.nfts != newValue.nfts {
                observers.forEach { $0.observer?.didUpdateNFTs(newValue.nfts) }
            }
            if oldValue.loadingState != newValue.loadingState {
                observers.forEach { $0.observer?.didUpdateLoadingState(newValue.loadingState) }
            }
        }
    }

    private var observers = [WeakWalletNFTStoreObserver]()
    private var loadingTask: Task<WalletNFTs, Never>?

    private nonisolated let wallet: Wallet
    private let repository: WalletNFTsRepository
    private let nftManagementStore: WalletNFTsManagementStore
    private let nftsService: AccountNFTService

    init(
        wallet: Wallet,
        repository: WalletNFTsRepository,
        nftManagementStore: WalletNFTsManagementStore,
        nftsService: AccountNFTService
    ) {
        self.wallet = wallet
        self.repository = repository
        self.nftManagementStore = nftManagementStore
        self.nftsService = nftsService

        state = StoreState(
            value: State(
                loadingState: .idle,
                nfts: .empty
            ),
            initialState: {
                State(
                    loadingState: .idle,
                    nfts: repository.get(wallet: wallet)
                )
            }
        )

        nftManagementStore.addObserver(self) { observer, event in
            switch event {
            case let .didUpdateState(wallet):
                guard wallet == observer.wallet else { return }
                Task {
                    await observer.didUpdateNFTsManagementStoreState()
                }
            }
        }
    }

    public func addObserver(_ observer: WalletNFTStoreObserver, notifyOnAdd: Bool = true) {
        let observers = self.observers.filter { $0.observer != nil }
        self.observers = observers + CollectionOfOne(
            WeakWalletNFTStoreObserver(
                observer: observer
            )
        )
        if notifyOnAdd {
            self.observers.forEach { $0.observer?.didUpdateNFTs(state.value.nfts) }
            self.observers.forEach { $0.observer?.didUpdateLoadingState(state.value.loadingState) }
        }
    }

    @discardableResult
    public func loadNFTs() async -> WalletNFTs {
        if let loadingTask {
            return await loadingTask.value
        } else {
            let task = Task<WalletNFTs, Never> {
                do {
                    let loadedNFTs = try await nftsService.loadAccountNFTs(
                        wallet: wallet,
                        collectionAddress: nil,
                        limit: nil,
                        offset: nil,
                        isIndirectOwnership: true
                    )
                    return handleNFTs(loadedNFTs)
                } catch {
                    return WalletNFTs(all: [], visible: [], hidden: [], spam: [], blacklistedCount: 0)
                }
            }
            self.loadingTask = task

            _state = State(
                loadingState: .loading,
                nfts: _state.nfts
            )

            let nfts = await task.value
            self.loadingTask = nil
            if !Task.isCancelled {
                try? self.repository.save(nfts: nfts, wallet: wallet)
                _state = State(loadingState: .idle, nfts: nfts)
            } else {
                _state = State(loadingState: .idle, nfts: _state.nfts)
            }
            return nfts
        }
    }

    private func didUpdateNFTsManagementStoreState() {
        let nfts = handleNFTs(state.value.nfts.all)
        _state = State(loadingState: _state.loadingState, nfts: nfts)
    }

    private func handleNFTs(_ nfts: [NFT]) -> WalletNFTs {
        var visible: [NFT] = []
        var hidden: [NFT] = []
        var spam: [NFT] = []
        var blacklistedCount = 0

        let managementStoreState = nftManagementStore.state
        for nft in nfts {
            guard !nft.isHidden else { continue }
            let state: NFTsManagementState.NFTState?
            if let collection = nft.collection {
                state = managementStoreState.nftStates[.collection(collection.address)]
            } else {
                state = managementStoreState.nftStates[.singleItem(nft.address)]
            }

            switch nft.trust {
            case .blacklist:
                blacklistedCount += 1
            case .graylist, .none, .unknown, .whitelist:
                switch state {
                case .spam:
                    spam.append(nft)
                case .hidden:
                    hidden.append(nft)
                default:
                    visible.append(nft)
                }
            }
        }

        return WalletNFTs(
            all: nfts,
            visible: visible,
            hidden: hidden,
            spam: spam,
            blacklistedCount: blacklistedCount
        )
    }
}

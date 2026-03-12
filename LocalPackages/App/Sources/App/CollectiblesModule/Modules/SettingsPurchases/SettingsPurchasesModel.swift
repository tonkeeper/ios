import Foundation
import KeeperCore
import TonSwift

final class SettingsPurchasesModel {
    enum Event {
        case didUpdateItems(State)
        case didUpdateManagementState(State)
    }

    struct State {
        let visible: [Item]
        let hidden: [Item]
        let approved: [Item]
        let spam: [Item]
        let collectionNfts: [NFTCollection: [NFT]]
        let blacklistedCount: Int
    }

    enum Item {
        case single(nft: NFT)
        case collection(collection: NFTCollection)

        var id: String {
            switch self {
            case let .single(nft):
                nft.address.toString()
            case let .collection(collection):
                collection.address.toString()
            }
        }
    }

    var didUpdate: ((Event) -> Void)?

    var state: State {
        getState()
    }

    private let wallet: Wallet
    private let walletNFTStore: WalletNFTStore
    private let accountNFTsManagementStore: WalletNFTsManagementStore
    private let updateQueue: DispatchQueue

    init(
        wallet: Wallet,
        walletNFTStore: WalletNFTStore,
        accountNFTsManagementStore: WalletNFTsManagementStore,
        updateQueue: DispatchQueue
    ) {
        self.wallet = wallet
        self.walletNFTStore = walletNFTStore
        self.accountNFTsManagementStore = accountNFTsManagementStore
        self.updateQueue = updateQueue

        Task { await walletNFTStore.addObserver(self) }
    }

    func hideItem(_ item: Item) {
        accountNFTsManagementStore.hideItem(item.nftManagementItem)
    }

    func showItem(_ item: Item) {
        accountNFTsManagementStore.showItem(item.nftManagementItem)
    }

    func isMarkedAsSpam(item: Item) -> Bool {
        let nftStates = accountNFTsManagementStore.state.nftStates
        return nftStates[item.nftManagementItem] == .spam
    }

    private func getState() -> State {
        let managementState = accountNFTsManagementStore.getState()
        return createState(nfts: walletNFTStore.state.value.nfts, managementState: managementState)
    }

    private func createState(nfts: WalletNFTs, managementState: NFTsManagementState) -> State {
        var collectionNFTs = [NFTCollection: [NFT]]()
        var addedCollections = Set<NFTCollection>()

        func map(nfts: [NFT]) -> [Item] {
            nfts.compactMap { nft in
                if let collection = nft.collection {
                    if var nfts = collectionNFTs[collection] {
                        nfts.append(nft)
                        collectionNFTs[collection] = nfts
                    } else {
                        collectionNFTs[collection] = [nft]
                    }
                    if !addedCollections.contains(collection) {
                        addedCollections.insert(collection)
                        return .collection(collection: collection)
                    } else {
                        return nil
                    }
                } else {
                    return .single(nft: nft)
                }
            }
        }

        return State(
            visible: map(nfts: nfts.visible),
            hidden: map(nfts: nfts.hidden),
            approved: [],
            spam: map(nfts: nfts.spam),
            collectionNfts: collectionNFTs,
            blacklistedCount: nfts.blacklistedCount
        )
    }
}

extension SettingsPurchasesModel: WalletNFTStoreObserver {
    func didUpdateNFTs(_ nfts: WalletNFTs) {
        let state = getState()
        didUpdate?(.didUpdateItems(state))
    }
}

private extension SettingsPurchasesModel.Item {
    var nftManagementItem: NFTManagementItem {
        switch self {
        case let .single(nft):
            return .singleItem(nft.address)
        case let .collection(collection):
            return .collection(collection.address)
        }
    }
}

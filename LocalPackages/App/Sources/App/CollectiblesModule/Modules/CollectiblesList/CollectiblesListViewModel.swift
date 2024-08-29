import Foundation
import TKUIKit
import KeeperCore
import TonSwift

protocol CollectiblesListModuleOutput: AnyObject {
  var didSelectNFT: ((NFT) -> Void)? { get set }
  var didUpdate: ((_ hasItems: Bool) -> Void)? { get set }
}

protocol CollectiblesListViewModel: AnyObject {
  var didUpdateSnapshot: ((CollectiblesListViewController.Snapshot) -> Void)? { get set }
  
  func viewDidLoad()
  func getNFTCellModel(identifier: String) -> CollectibleCollectionViewCell.Model?
  func didSelectNftAt(index: Int)
}

final class CollectiblesListViewModelImplementation: CollectiblesListViewModel, CollectiblesListModuleOutput {
  
  // MARK: - CollectiblesListModuleOutput
  
  var didSelectNFT: ((NFT) -> Void)?
  var didUpdate: ((_ hasItems: Bool) -> Void)?
  
  // MARK: - CollectiblesListViewModel
  
  var didUpdateSnapshot: ((CollectiblesListViewController.Snapshot) -> Void)?
  var didLoadNFTs: (([CollectibleCollectionViewCell.Model]) -> Void)?
  
  func viewDidLoad() {
    accountNftsStore.addObserver(self, notifyOnAdded: false) { observer, newState, oldState in
      DispatchQueue.main.async {
        guard observer.walletsStore.getState().activeWallet == observer.wallet else { return }
        let nftsManagementState = observer.nftManagementStore.getState()
        observer.update(nftsStoreStates: newState, managementState: nftsManagementState)
      }
    }
      let nftsStoreState =  accountNftsStore.getState()
      let nftsManagementState =  nftManagementStore.getState()
      update(
        nftsStoreStates: nftsStoreState,
        managementState: nftsManagementState
      )
  }
  
  func getNFTCellModel(identifier: String) -> CollectibleCollectionViewCell.Model? {
    models[identifier]
  }
  
  func didSelectNftAt(index: Int) {
    guard index < nfts.count else { return }
    let nft = nfts[index]
    didSelectNFT?(nft)
  }
  
  // MARK: - State
  
  private var models = [String: CollectibleCollectionViewCell.Model]()
  private var nfts = [NFT]()
  
  // MARK: - Mapper
  
  private let collectiblesListMapper = CollectiblesListMapper()
  
  // MARK: - Dependencies
  
  private let wallet: Wallet
  private let walletsStore: WalletsStore
  private let accountNftsLoader: AccountNftsLoader
  private let accountNftsStore: AccountNFTsStore
  private let nftManagementStore: AccountNFTsManagementStore
  
  // MARK: - Init
  
  init(wallet: Wallet,
       walletsStore: WalletsStore,
       accountNftsLoader: AccountNftsLoader,
       accountNftsStore: AccountNFTsStore,
       nftManagementStore: AccountNFTsManagementStore) {
    self.wallet = wallet
    self.walletsStore = walletsStore
    self.accountNftsLoader = accountNftsLoader
    self.accountNftsStore = accountNftsStore
    self.nftManagementStore = nftManagementStore
  }
}

private extension CollectiblesListViewModelImplementation {
  func update(nftsStoreStates: [FriendlyAddress: [NFT]],
              managementState: NFTsManagementState) {
    guard let address = try? wallet.friendlyAddress,
          let nftStoreState = nftsStoreStates[address] else {
      didUpdate?(false)
      return
    }
    
    let filteredState = self.filterSpamNFTItems(
      state: nftStoreState,
      managementState: managementState)
    let snapshot = self.createSnapshot(state: filteredState)
    let models = self.createModels(state: filteredState)
    let hasItems = !filteredState.isEmpty
    self.nfts = filteredState
    self.didUpdate?(hasItems)
    self.models = models
    self.didUpdateSnapshot?(snapshot)
  }
  
  func createSnapshot(state: [NFT]) -> CollectiblesListViewController.Snapshot {
    var snapshot = CollectiblesListViewController.Snapshot()
    snapshot.appendSections([.all])
    snapshot.appendItems(state.map { .nft(identifier: $0.address.toString()) }, toSection: .all)

    return snapshot
  }
  
  func createModels(state: [NFT]) -> [String: CollectibleCollectionViewCell.Model] {
    return state.reduce(into: [String: CollectibleCollectionViewCell.Model](), { result, item in
      let model = collectiblesListMapper.map(nft: item)
      let identifier = item.address.toString()
      result[identifier] = model
    })
  }
  
  func filterSpamNFTItems(state: [NFT],
                          managementState: NFTsManagementState) -> [NFT] {
    
    func filter(items: [NFT]) -> [NFT] {
      items.filter {
        let state: NFTsManagementState.NFTState?
        if let collection = $0.collection {
          state = managementState.nftStates[.collection(collection.address)]
        } else {
          state = managementState.nftStates[.singleItem($0.address)]
        }
        
        switch $0.trust {
        case .blacklist:
          return state == .visible
        case .graylist, .none, .unknown, .whitelist:
          return state != .hidden
        }
      }
    }
    return filter(items: state)
  }
}

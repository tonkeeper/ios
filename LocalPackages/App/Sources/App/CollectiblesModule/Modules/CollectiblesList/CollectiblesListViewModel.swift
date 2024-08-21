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
//  func loadNext()
//  func didSelectNftAt(index: Int)
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
//    Task {
//      let nft = await collectiblesListController.nftAt(index: index)
//      await MainActor.run {
//        didSelectNFT?(nft)
//      }
//    }
  }
  
  // MARK: - State
  
  private var models = [String: CollectibleCollectionViewCell.Model]()
  
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
  func update(nftsStoreStates: [FriendlyAddress: AccountNFTsStore.State],
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
    let hasItems = self.hasItems(state: filteredState)
    self.didUpdate?(hasItems)
    self.models = models
    self.didUpdateSnapshot?(snapshot)
  }
  
  func createSnapshot(state: AccountNFTsStore.State) -> CollectiblesListViewController.Snapshot {
    var snapshot = CollectiblesListViewController.Snapshot()
    switch state {
    case .loading(let cached):
      snapshot.appendSections([.all])
      snapshot.appendItems(cached.map { .nft(identifier: $0.address.toString()) }, toSection: .all)
    case .items(let items):
      snapshot.appendSections([.all])
      snapshot.appendItems(items.map { .nft(identifier: $0.address.toString()) }, toSection: .all)
    }
    
    return snapshot
  }
  
  func createModels(state: AccountNFTsStore.State) -> [String: CollectibleCollectionViewCell.Model] {
    switch state {
    case .items(let items):
      return items.reduce(into: [String: CollectibleCollectionViewCell.Model](), { result, item in
        let model = collectiblesListMapper.map(nft: item)
        let identifier = item.address.toString()
        result[identifier] = model
      })
    case .loading(let cached):
      return cached.reduce(into: [String: CollectibleCollectionViewCell.Model](), { result, item in
        let model = collectiblesListMapper.map(nft: item)
        let identifier = item.address.toString()
        result[identifier] = model
      })
    }
  }
  
  func hasItems(state: AccountNFTsStore.State) -> Bool {
    switch state {
    case .items(let items):
      return !items.isEmpty
    case .loading:
      return true
    }
  }
  
  func filterSpamNFTItems(state: AccountNFTsStore.State,
                          managementState: NFTsManagementState) -> AccountNFTsStore.State {
    
    func filter(items: [NFT]) -> [NFT] {
      items.filter {
        switch $0.trust {
        case .blacklist:
          managementState.nftStates[$0.address] == .visible
        case .graylist, .none, .unknown, .whitelist:
          managementState.nftStates[$0.address] != .hidden
        }
      }
    }
    
    switch state {
    case .loading(let cached):
      return .loading(cached: filter(items: cached))
    case .items(let items):
      return .items(item: filter(items: items))
    }
  }
}

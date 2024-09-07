import Foundation
import TKUIKit
import KeeperCore
import TonSwift

protocol CollectiblesListModuleOutput: AnyObject {
  var didSelectNFT: ((NFT, _ wallet: Wallet) -> Void)? { get set }
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
  
  var didSelectNFT: ((NFT, _ wallet: Wallet) -> Void)?
  var didUpdate: ((_ hasItems: Bool) -> Void)?
  
  // MARK: - CollectiblesListViewModel
  
  var didUpdateSnapshot: ((CollectiblesListViewController.Snapshot) -> Void)?
  var didLoadNFTs: (([CollectibleCollectionViewCell.Model]) -> Void)?
  
  func viewDidLoad() {
    walletNFTStore.addObserver(self) { observer, event in
      switch event {
      case .didUpdateNFTs(let wallet):
        guard self.wallet == wallet else { return }
        DispatchQueue.main.async {
          let nfts = observer.walletNFTStore.getState()[wallet] ?? []
          let nftsManagementState = observer.nftManagementStore.getState()
          observer.update(nfts: nfts, managementState: nftsManagementState)
        }
      }
    }
    
    let nfts = walletNFTStore.getState()[wallet] ?? []
    let nftsManagementState = nftManagementStore.getState()
    update(
      nfts: nfts,
      managementState: nftsManagementState
    )
  }
  
  func getNFTCellModel(identifier: String) -> CollectibleCollectionViewCell.Model? {
    models[identifier]
  }
  
  func didSelectNftAt(index: Int) {
    guard index < nfts.count else { return }
    let nft = nfts[index]
    didSelectNFT?(nft, wallet)
  }
  
  // MARK: - State
  
  private var models = [String: CollectibleCollectionViewCell.Model]()
  private var nfts = [NFT]()
  
  // MARK: - Mapper
  
  private let collectiblesListMapper = CollectiblesListMapper()
  
  // MARK: - Dependencies
  
  private let wallet: Wallet
  private let walletsStore: WalletsStore
  private let walletNFTStore: WalletNFTStore
  private let nftManagementStore: AccountNFTsManagementStore
  
  // MARK: - Init
  
  init(wallet: Wallet,
       walletsStore: WalletsStore,
       walletNFTStore: WalletNFTStore,
       nftManagementStore: AccountNFTsManagementStore) {
    self.wallet = wallet
    self.walletsStore = walletsStore
    self.walletNFTStore = walletNFTStore
    self.nftManagementStore = nftManagementStore
  }
}

private extension CollectiblesListViewModelImplementation {
  func update(nfts: [NFT],
              managementState: NFTsManagementState) {
    guard !nfts.isEmpty else {
      didUpdate?(false)
      return
    }
    let filteredState = self.filterSpamNFTItems(
      nfts: nfts,
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
  
  func filterSpamNFTItems(nfts: [NFT],
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
    return filter(items: nfts)
  }
}

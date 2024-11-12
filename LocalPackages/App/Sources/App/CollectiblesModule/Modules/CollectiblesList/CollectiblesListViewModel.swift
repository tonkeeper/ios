import Foundation
import TKUIKit
import KeeperCore
import TonSwift

protocol CollectiblesListModuleOutput: AnyObject {
  var didSelectNFT: ((NFT, _ wallet: Wallet) -> Void)? { get set }
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
  
  // MARK: - CollectiblesListViewModel
  
  var didUpdateSnapshot: ((CollectiblesListViewController.Snapshot) -> Void)?
  var didLoadNFTs: (([CollectibleCollectionViewCell.Model]) -> Void)?
  
  func viewDidLoad() {
    walletNFTsManagedStore.addObserver(self) { observer, event in
      switch event {
      case .didUpdateNFTs(let wallet):
        guard observer.wallet == wallet else { return }
        DispatchQueue.main.async {
          observer.update()
        }
      }
    }
    
    appSettingsStore.addObserver(self) { observer, event in
      switch event {
      case .didUpdateIsSecureMode:
        DispatchQueue.main.async {
          observer.update()
        }
      default: break
      }
    }
    
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
  
  // MARK: - State
  
  private var models = [String: CollectibleCollectionViewCell.Model]()
  private var nfts = [NFT]()
  
  // MARK: - Mapper
  
  private lazy var collectiblesListMapper = CollectiblesListMapper(
    walletNftManagementStore: walletNftManagementStore
  )

  // MARK: - Dependencies
  
  private let wallet: Wallet
  private let walletNFTsManagedStore: WalletNFTsManagedStore
  private let walletNftManagementStore: WalletNFTsManagementStore
  private let appSettingsStore: AppSettingsStore
  
  // MARK: - Init
  
  init(wallet: Wallet,
       walletNFTsManagedStore: WalletNFTsManagedStore,
       walletNftManagementStore: WalletNFTsManagementStore,
       appSettingsStore: AppSettingsStore) {
    self.wallet = wallet
    self.walletNFTsManagedStore = walletNFTsManagedStore
    self.walletNftManagementStore = walletNftManagementStore
    self.appSettingsStore = appSettingsStore
  }
}

private extension CollectiblesListViewModelImplementation {
  func update() {
    let nfts = walletNFTsManagedStore.getState()
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
  
  func createSnapshot(state: [NFT]) -> CollectiblesListViewController.Snapshot {
    var snapshot = CollectiblesListViewController.Snapshot()
    snapshot.appendSections([.all])
    snapshot.appendItems(state.map { .nft(identifier: $0.address.toString()) }, toSection: .all)
    if #available(iOS 15.0, *) {
      snapshot.reconfigureItems(snapshot.itemIdentifiers)
    } else {
      snapshot.reloadItems(snapshot.itemIdentifiers)
    }

    return snapshot
  }
  
  func createModels(state: [NFT], isSecureMode: Bool) -> [String: CollectibleCollectionViewCell.Model] {
    return state.reduce(into: [String: CollectibleCollectionViewCell.Model](), { result, item in
      let currentState = currentLocalState(item)
      let model = collectiblesListMapper.map(nft: item, isSecureMode: isSecureMode)
      let identifier = item.address.toString()
      result[identifier] = model
    })
  }

  func currentLocalState(_ item: NFT) -> NFTsManagementState.NFTState? {
    let state: NFTsManagementState.NFTState?
    if let collection = item.collection {
      state = walletNftManagementStore.getState().nftStates[.collection(collection.address)]
    } else {
      state = walletNftManagementStore.getState().nftStates[.singleItem(item.address)]
    }
    return state
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
          return state != .hidden && state != .spam
        }
      }
    }
    return filter(items: nfts)
  }
}

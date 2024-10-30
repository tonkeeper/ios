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
    let spam: [Item]
    let collectionNfts: [NFTCollection: [NFT]]
  }
  
  enum Item {
    case single(nft: NFT)
    case collection(collection: NFTCollection)
    
    var id: String {
      switch self {
      case .single(let nft):
        nft.address.toString()
      case .collection(let collection):
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
  
  init(wallet: Wallet, 
       walletNFTStore: WalletNFTStore,
       accountNFTsManagementStore: WalletNFTsManagementStore,
       updateQueue: DispatchQueue) {
    self.wallet = wallet
    self.walletNFTStore = walletNFTStore
    self.accountNFTsManagementStore = accountNFTsManagementStore
    self.updateQueue = updateQueue
    
    walletNFTStore.addObserver(self) { observer, event in
      observer.updateQueue.async {
        switch event {
        case .didUpdateNFTs(let wallet):
          guard wallet == self.wallet else { return }
          let state = observer.getState()
          observer.didUpdate?(.didUpdateItems(state))
        }
      }
    }
    
    accountNFTsManagementStore.addObserver(self) { observer, event in
      observer.updateQueue.async {
        switch event {
        case .didUpdateState(let wallet):
          guard wallet == self.wallet else { return }
          let state = observer.getState()
          observer.didUpdate?(.didUpdateManagementState(state))
        }
      }
    }
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
    guard let nfts = walletNFTStore.state[wallet] else {
      return State(
        visible: [],
        hidden: [],
        spam: [],
        collectionNfts: [:]
      )
    }
    
    let managementState = accountNFTsManagementStore.getState()
    let state = createState(nfts: nfts, managementState: managementState)
    return state
  }
  
  private func createState(nfts: [NFT], managementState: NFTsManagementState) -> State {
    var items = [Item]()
    var collectionNFTs = [NFTCollection: [NFT]]()
    var addedCollections = Set<NFTCollection>()
    
    var visible = [Item]()
    var hidden = [Item]()
    var spam = [Item]()
    
    for nft in nfts {
      if let collection = nft.collection {
        if !addedCollections.contains(collection) {
          items.append(.collection(collection: collection))
          addedCollections.insert(collection)
          
          switch nft.trust {
          case .blacklist:
            switch managementState.nftStates[.collection(collection.address)] {
            case .none, .spam:
              spam.append(.collection(collection: collection))
            case .hidden:
              hidden.append(.collection(collection: collection))
            case .visible:
              visible.append(.collection(collection: collection))
            }
          case .none, .whitelist, .graylist, .unknown:
            switch managementState.nftStates[.collection(collection.address)] {
            case .spam:
              spam.append(.collection(collection: collection))
            case .hidden:
              hidden.append(.collection(collection: collection))
            case .visible, .none:
              visible.append(.collection(collection: collection))
            }
          }
        }
        if var nfts = collectionNFTs[collection] {
          nfts.append(nft)
          collectionNFTs[collection] = nfts
        } else {
          collectionNFTs[collection] = [nft]
        }
        
      } else {
        items.append(.single(nft: nft))
        
        switch nft.trust {
        case .blacklist:
          switch managementState.nftStates[.singleItem(nft.address)] {
          case .none, .spam:
            spam.append(.single(nft: nft))
          case .hidden:
            hidden.append(.single(nft: nft))
          case .visible:
            visible.append(.single(nft: nft))
          }
        case .none, .whitelist, .graylist, .unknown:
          switch managementState.nftStates[.singleItem(nft.address)] {
          case .spam:
            spam.append(.single(nft: nft))
          case .hidden:
            hidden.append(.single(nft: nft))
          case .visible, .none:
            visible.append(.single(nft: nft))
          }
        }
      }
    }
    
    return State(
      visible: visible,
      hidden: hidden,
      spam: spam,
      collectionNfts: collectionNFTs
    )
  }
}

fileprivate extension SettingsPurchasesModel.Item {
  var nftManagementItem: NFTManagementItem {
    switch self {
    case .single(let nft):
      return .singleItem(nft.address)
    case .collection(let collection):
      return .collection(collection.address)
    }
  }
}

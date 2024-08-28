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
    queue.sync {
      if let _state {
        return _state
      } else {
        let state = getState()
        _state = state
        return state
      }
    }
  }
  private var _state: State?
  
  private let queue = DispatchQueue(label: "SettingsPurchasesModelQueue")
  
  private let wallet: Wallet
  private let accountNFTsStore: AccountNFTsStore
  private let accountNFTsManagementStore: AccountNFTsManagementStore
  
  init(wallet: Wallet, 
       accountNFTsStore: AccountNFTsStore,
       accountNFTsManagementStore: AccountNFTsManagementStore) {
    self.wallet = wallet
    self.accountNFTsStore = accountNFTsStore
    self.accountNFTsManagementStore = accountNFTsManagementStore
    
    accountNFTsStore.addObserver(self, notifyOnAdded: false) { observer, newState, oldState in
      observer.queue.async {
        let state = observer.getState()
        observer._state = state
        observer.didUpdate?(.didUpdateItems(state))
      }
    }
    
    accountNFTsManagementStore.addObserver(self, notifyOnAdded: false) { observer, newState, oldState in
      observer.queue.async {
        let state = observer.getState()
        observer._state = state
        observer.didUpdate?(.didUpdateManagementState(state))
      }
    }
  }
  
  func hideItem(_ item: Item) {
    Task {
      await accountNFTsManagementStore.hideItem(item.nftManagementItem)
    }
  }
  
  func showItem(_ item: Item) {
    Task {
      await accountNFTsManagementStore.showItem(item.nftManagementItem)
    }
  }
  
  private func getState() -> State {
    guard let address = try? wallet.friendlyAddress,
          let nfts = accountNFTsStore.getState()[address]?.nfts else {
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

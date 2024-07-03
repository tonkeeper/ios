import Foundation
import KeeperCore
import BigInt
import TonSwift
import TKCore

final class WalletBalanceBalanceModel {
  struct BalanceListItem {
    enum Image {
      case ton
      case url(URL?)
    }
    enum ItemType {
      case ton
      case jetton(JettonItem)
    }
    
    var id: String {
      switch type {
      case .ton:
        return TonInfo.symbol
      case .jetton(let jettonItem):
        return jettonItem.jettonInfo.address.toString()
      }
    }
    
    let type: ItemType
    let title: String
    let image: Image
    let amount: BigUInt
    let tag: String?
    let fractionalDigits: Int
    let currency: Currency
    let converted: Decimal
    let price: Decimal
    let diff: String?
  }
  
  private let actor = SerialActor()

  var didUpdateItems: (([BalanceListItem], _ isSecure: Bool) -> Void)? {
    didSet {
      Task {
        await self.actor.addTask(block: {
          let activeWallet = await self.walletsStore.getState().activeWallet
          guard let address = try? activeWallet.friendlyAddress else { return }
          let balance = await self.convertedBalanceStore.getState()[address]?.balance
          let isSecure = await self.secureMode.isSecure
          self.update(balance: balance, isSecure: isSecure)
        })
      }
    }
  }
  
  private let walletsStore: WalletsStoreV2
  private let convertedBalanceStore: ConvertedBalanceStoreV2
  private let secureMode: SecureMode
  
  init(walletsStore: WalletsStoreV2,
       convertedBalanceStore: ConvertedBalanceStoreV2,
       secureMode: SecureMode) {
    self.walletsStore = walletsStore
    self.convertedBalanceStore = convertedBalanceStore
    self.secureMode = secureMode
    walletsStore.addObserver(self, notifyOnAdded: true) { observer, newWalletsState, oldWalletsState in
      Task {
        await observer.didUpdateWalletsState(newWalletsState: newWalletsState, oldWalletsState: oldWalletsState)
      }
    }
    convertedBalanceStore.addObserver(self, notifyOnAdded: true) { observer, newState, oldState in
      Task {
        await observer.didUpdateBalances(newState, oldState)
      }
    }
    secureMode.addObserver(self, notifyOnAdded: false) { observer, newState, _ in
      Task {
        await observer.didUpdateSecureMode(newState)
      }
    }
  }
  
  private func didUpdateWalletsState(newWalletsState: WalletsState,
                                     oldWalletsState: WalletsState?) async {
    await actor.addTask(block: {
      guard newWalletsState.activeWallet != oldWalletsState?.activeWallet else { return }
      guard let address = try? newWalletsState.activeWallet.friendlyAddress else { return }
      let balance = await self.convertedBalanceStore.getState()[address]?.balance
      let isSecure = await self.secureMode.isSecure
      self.update(balance: balance, isSecure: isSecure)
    })
  }
  
  private func didUpdateBalances(_ newBalances: [FriendlyAddress: ConvertedBalanceState],
                                 _ oldBalances: [FriendlyAddress: ConvertedBalanceState]?) async {
    await actor.addTask(block: {
      let activeWallet = await self.walletsStore.getState().activeWallet
      guard let address = try? activeWallet.friendlyAddress else { return }
      guard newBalances[address] != oldBalances?[address] else { return }
      let isSecure = await self.secureMode.isSecure
      self.update(balance: newBalances[address]?.balance, isSecure: isSecure)
    })
  }
  
  private func didUpdateSecureMode(_ isSecure: Bool) async {
    await actor.addTask(block: {
      let activeWallet = await self.walletsStore.getState().activeWallet
      guard let address = try? activeWallet.friendlyAddress else { return }
      let balance = await self.convertedBalanceStore.getState()[address]?.balance
      self.update(balance: balance, isSecure: isSecure)
    })
  }
  
  private func update(balance: ConvertedBalance?, isSecure: Bool) {
    var items = [BalanceListItem]()
    if let balance {
      let tonItem = BalanceListItem(
        type: .ton,
        title: TonInfo.symbol,
        image: .ton,
        amount: BigUInt(balance.tonBalance.tonBalance.amount),
        tag: nil,
        fractionalDigits: TonInfo.fractionDigits,
        currency: balance.currency,
        converted: balance.tonBalance.converted,
        price: balance.tonBalance.price,
        diff: balance.tonBalance.diff
      )
      items.append(tonItem)
      
      let jettonItems = balance.jettonsBalance
        .sorted(by: { left, right in
          if left.jettonBalance.item.jettonInfo.isTonUSDT {
            return true
          } else if right.jettonBalance.item.jettonInfo.isTonUSDT {
            return false
          }
          
          switch (left.jettonBalance.item.jettonInfo.verification, right.jettonBalance.item.jettonInfo.verification) {
          case (.whitelist, .whitelist):
            return left.converted > right.converted ? true : false
          case (.whitelist, _):
            return true
          case (_, .whitelist):
            return false
          default:
            return left.converted > right.converted ? true : false
          }
        })
        .map {
          var tag: String?
          if $0.jettonBalance.item.jettonInfo.isTonUSDT {
            tag = "TON"
          }
          
          return BalanceListItem(
            type: .jetton($0.jettonBalance.item),
            title: $0.jettonBalance.item.jettonInfo.symbol ?? $0.jettonBalance.item.jettonInfo.name,
            image: .url($0.jettonBalance.item.jettonInfo.imageURL),
            amount: $0.jettonBalance.quantity,
            tag: tag,
            fractionalDigits: $0.jettonBalance.item.jettonInfo.fractionDigits,
            currency: balance.currency,
            converted: $0.converted,
            price: $0.price,
            diff: $0.diff
          )
      }
      items.append(contentsOf: jettonItems)
    }
    didUpdateItems?(items, isSecure)
  }
}

import Foundation
import KeeperCore
import BigInt
import TonSwift
import TKCore
import TKLocalize

final class WalletBalanceBalanceModel {
  struct BalanceListItem {
    enum Image {
      case ton
      case url(URL?)
    }
    enum ItemType {
      case ton
      case jetton(JettonItem)
      case stacking(AccountStackingInfo, poolInfo: StackingPoolInfo?)
    }
    
    var id: String {
      switch type {
      case .ton:
        return TonInfo.symbol
      case .jetton(let jettonItem):
        return jettonItem.jettonInfo.address.toString()
      case .stacking(let stackingInfo, _):
        return stackingInfo.pool.toString()
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
          let stackingPools = await self.stackingPoolsStore.getStackingPools(address: address)
          self.update(balance: balance,
                      stackingPools: stackingPools,
                      isSecure: isSecure)
        })
      }
    }
  }
  
  private let walletsStore: WalletsStoreV2
  private let convertedBalanceStore: ConvertedBalanceStoreV2
  private let stackingPoolsStore: StakingPoolsStore
  private let secureMode: SecureMode
  
  init(walletsStore: WalletsStoreV2,
       convertedBalanceStore: ConvertedBalanceStoreV2,
       stackingPoolsStore: StakingPoolsStore,
       secureMode: SecureMode) {
    self.walletsStore = walletsStore
    self.convertedBalanceStore = convertedBalanceStore
    self.stackingPoolsStore = stackingPoolsStore
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
      let stackingPools = await self.stackingPoolsStore.getStackingPools(address: address)
      self.update(balance: balance,
                  stackingPools: stackingPools,
                  isSecure: isSecure)
    })
  }
  
  private func didUpdateBalances(_ newBalances: [FriendlyAddress: ConvertedBalanceState],
                                 _ oldBalances: [FriendlyAddress: ConvertedBalanceState]?) async {
    await actor.addTask(block: {
      let activeWallet = await self.walletsStore.getState().activeWallet
      guard let address = try? activeWallet.friendlyAddress else { return }
      guard newBalances[address] != oldBalances?[address] else { return }
      let isSecure = await self.secureMode.isSecure
      let stackingPools = await self.stackingPoolsStore.getStackingPools(address: address)
      self.update(balance: newBalances[address]?.balance,
                  stackingPools: stackingPools,
                  isSecure: isSecure)
    })
  }
  
  private func didUpdateSecureMode(_ isSecure: Bool) async {
    await actor.addTask(block: {
      let activeWallet = await self.walletsStore.getState().activeWallet
      guard let address = try? activeWallet.friendlyAddress else { return }
      let balance = await self.convertedBalanceStore.getState()[address]?.balance
      let stackingPools = await self.stackingPoolsStore.getStackingPools(address: address)
      self.update(balance: balance, 
                  stackingPools: stackingPools,
                  isSecure: isSecure)
    })
  }
  
  private func update(balance: ConvertedBalance?,
                      stackingPools: [StackingPoolInfo],
                      isSecure: Bool) {
    guard let balance else {
      didUpdateItems?([], isSecure)
      return
    }
    var jettonsBalance = balance.jettonsBalance
    var stackingBalance = balance.stackingBalance
    
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
    
    var tonUSDTItem: BalanceListItem?
    if let usdtJettonIndex = jettonsBalance.firstIndex(where: {
      $0.jettonBalance.item.jettonInfo.address == JettonMasterAddress.tonUSDT
    }) {
      let usdtJetton = jettonsBalance[usdtJettonIndex]
      jettonsBalance.remove(at: usdtJettonIndex)
      tonUSDTItem = BalanceListItem(
        type: .jetton(usdtJetton.jettonBalance.item),
        title: usdtJetton.jettonBalance.item.jettonInfo.symbol ?? usdtJetton.jettonBalance.item.jettonInfo.name,
        image: .url(usdtJetton.jettonBalance.item.jettonInfo.imageURL),
        amount: usdtJetton.jettonBalance.quantity,
        tag: "TON",
        fractionalDigits: usdtJetton.jettonBalance.item.jettonInfo.fractionDigits,
        currency: balance.currency,
        converted: usdtJetton.converted,
        price: usdtJetton.price,
        diff: usdtJetton.diff
      )
    }
    
    var tonstakersItem: BalanceListItem?
    if let tonstakersJettonIndex = jettonsBalance.firstIndex(where: {
      $0.jettonBalance.item.jettonInfo.address == JettonMasterAddress.tonstakers
    }) {
      let tonstakersJetton = jettonsBalance[tonstakersJettonIndex]
      jettonsBalance.remove(at: tonstakersJettonIndex)
      if let tonstakersPool = stackingPools.first(where: { $0.liquidJettonMaster == JettonMasterAddress.tonstakers }) {
        var tonstackerBalance: ConvertedStakingBalance?
        if let tonstakerInfoIndex = stackingBalance.firstIndex(where: { $0.stackingInfo.pool == tonstakersPool.address }) {
          tonstackerBalance = stackingBalance[tonstakerInfoIndex]
          stackingBalance.remove(at: tonstakerInfoIndex)
        }
        
        let amount: BigUInt
        let fractionDigits: Int
        if let tonRate = tonstakersJetton.jettonBalance.rates[.TON] {
          (amount, fractionDigits) = RateConverter().convert(amount: tonstakersJetton.jettonBalance.quantity,
                                           amountFractionLength: tonstakersJetton.jettonBalance.item.jettonInfo.fractionDigits,
                                           rate: tonRate)
        } else {
          amount = 0
          fractionDigits = 0
        }
        
        let info = AccountStackingInfo(
          pool: tonstakersPool.address,
          amount: Int64(tonstakersJetton.jettonBalance.quantity),
          pendingDeposit: tonstackerBalance?.stackingInfo.pendingDeposit ?? 0,
          pendingWithdraw:tonstackerBalance?.stackingInfo.pendingWithdraw ?? 0,
          readyWithdraw: tonstackerBalance?.stackingInfo.readyWithdraw ?? 0
        )
        tonstakersItem = BalanceListItem(
          type: .stacking(info, poolInfo: tonstakersPool),
          title: TKLocales.BalanceList.StackingItem.title,
          image: .ton,
          amount: amount,
          tag: nil,
          fractionalDigits: fractionDigits,
          currency: balance.currency,
          converted: tonstakersJetton.converted,
          price: tonstakersJetton.price,
          diff: nil
        )
      }
      
      //      if let tonstackerStakingInfo = stackingBalance.firstIndex(where: { $0.stackingInfo. })
    }
    //    if let tsTONJettonIndex = jettonsBalance.firstIndex(where: { $0.jettonBalance.item.jettonInfo.isTsTon }) {
    //      let tsTonJettob = jettonsBalance[tsTONJettonIndex]
    //      jettonsBalance.remove(at: tsTONJettonIndex)
    //      tonStackersItem = BalanceListItem(
    //        type: .stacking(AccountStackingInfo(pool: <#T##Address#>, amount: <#T##Int64#>, pendingDeposit: <#T##Int64#>, pendingWithdraw: <#T##Int64#>, readyWithdraw: <#T##Int64#>), poolInfo: <#T##StackingPoolInfo?#>),
    //        title: <#T##String#>,
    //        image: <#T##BalanceListItem.Image#>,
    //        amount: <#T##BigUInt#>,
    //        tag: <#T##String?#>,
    //        fractionalDigits: <#T##Int#>,
    //        currency: <#T##Currency#>,
    //        converted: <#T##Decimal#>,
    //        price: <#T##Decimal#>,
    //        diff: <#T##String?#>
    //      )
    //    }
    
    let stackingItems = stackingBalance
      .sorted { left, right in
        left.converted > right.converted
      }
      .map { stakingItem in
        let stackingPool = stackingPools.first(where: { $0.address == stakingItem.stackingInfo.pool  })
        return BalanceListItem(
          type: .stacking(stakingItem.stackingInfo, poolInfo: stackingPool),
          title: TKLocales.BalanceList.StackingItem.title,
          image: .ton,
          amount: BigUInt(stakingItem.stackingInfo.amount),
          tag: nil,
          fractionalDigits: TonInfo.fractionDigits,
          currency: balance.currency,
          converted: stakingItem.converted,
          price: stakingItem.price,
          diff: nil
        )
      }
    
    let jettonItems = jettonsBalance
      .sorted(by: { left, right in
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
        return BalanceListItem(
          type: .jetton($0.jettonBalance.item),
          title: $0.jettonBalance.item.jettonInfo.symbol ?? $0.jettonBalance.item.jettonInfo.name,
          image: .url($0.jettonBalance.item.jettonInfo.imageURL),
          amount: $0.jettonBalance.quantity,
          tag: nil,
          fractionalDigits: $0.jettonBalance.item.jettonInfo.fractionDigits,
          currency: balance.currency,
          converted: $0.converted,
          price: $0.price,
          diff: $0.diff
        )
      }
    var items = [BalanceListItem]()
    items.append(tonItem)
    if let tonUSDTItem {
      items.append(tonUSDTItem)
    }
    items.append(contentsOf: stackingItems)
    if let tonstakersItem {
      items.append(tonstakersItem)
    }
    items.append(contentsOf: jettonItems)
    
    didUpdateItems?(items, isSecure)
  }
}

import Foundation
import KeeperCore
import BigInt
import TonSwift
import TKCore
import TKLocalize

final class WalletBalanceBalanceModel {
  struct BalanceListTonItem {
    let id: String
    let title: String
    let amount: BigUInt
    let fractionalDigits: Int
    let currency: Currency
    let converted: Decimal
    let price: Decimal
    let diff: String?
  }
  
  struct BalanceListJettonItem {
    let id: String
    let jetton: JettonItem
    let amount: BigUInt
    let fractionalDigits: Int
    let tag: String?
    let currency: Currency
    let converted: Decimal
    let price: Decimal
    let diff: String?
  }
  
  struct BalanceListStakingItem {
    let id: String
    let info: AccountStackingInfo
    let poolInfo: StackingPoolInfo?
    let currency: Currency
    let converted: Decimal
    let price: Decimal
  }
  
  struct BalanceListItems {
    let tonItem: BalanceListTonItem?
    let usdtItem: BalanceListJettonItem?
    let jettonsItems: [BalanceListJettonItem]
    let stakingItems: [BalanceListStakingItem]
  }

  private let actor = SerialActor()

  var didUpdateItems: ((BalanceListItems, _ isSecure: Bool) -> Void)? {
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
      didUpdateItems?(
        BalanceListItems(
          tonItem: nil,
          usdtItem: nil,
          jettonsItems: [],
          stakingItems: []
        ),
        isSecure
      )
      return
    }
    var tonItems = [BalanceListTonItem]()
    var jettonItems = [BalanceListJettonItem]()
    var stakingItems = [BalanceListStakingItem]()
    
    var jettonsBalance = balance.jettonsBalance
    var stackingBalance = balance.stackingBalance
    
    let tonItem = BalanceListTonItem(
      id: TonInfo.symbol,
      title: TonInfo.symbol,
      amount: BigUInt(balance.tonBalance.tonBalance.amount),
      fractionalDigits: TonInfo.fractionDigits,
      currency: balance.currency,
      converted: balance.tonBalance.converted,
      price: balance.tonBalance.price,
      diff: balance.tonBalance.diff
    )
    tonItems.append(tonItem)
    
    var tonUSDTItem: BalanceListJettonItem?
    if let usdtJettonIndex = jettonsBalance.firstIndex(where: {
      $0.jettonBalance.item.jettonInfo.address == JettonMasterAddress.tonUSDT
    }) {
      let usdtJetton = jettonsBalance[usdtJettonIndex]
      jettonsBalance.remove(at: usdtJettonIndex)
      tonUSDTItem = BalanceListJettonItem(
        id: usdtJetton.jettonBalance.item.jettonInfo.address.toString(),
        jetton: usdtJetton.jettonBalance.item,
        amount: usdtJetton.jettonBalance.quantity,
        fractionalDigits: usdtJetton.jettonBalance.item.jettonInfo.fractionDigits,
        tag: "TON",
        currency: balance.currency,
        converted: usdtJetton.converted,
        price: usdtJetton.price,
        diff: usdtJetton.diff
      )
    }
    
    var tonstakersItem: BalanceListStakingItem?
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
        
        var amount: Int64 = 0
        if let tonRate = tonstakersJetton.jettonBalance.rates[.TON] {
          let converted = RateConverter().convertToDecimal(
            amount: tonstakersJetton.jettonBalance.quantity,
            amountFractionLength: tonstakersJetton.jettonBalance.item.jettonInfo.fractionDigits,
            rate: tonRate
          )
          let convertedFractionLength = min(Int16(TonInfo.fractionDigits),max(Int16(-converted.exponent), 0))
          amount = Int64(NSDecimalNumber(decimal: converted)
            .multiplying(byPowerOf10: convertedFractionLength).doubleValue)
        }
        
        let info = AccountStackingInfo(
          pool: tonstakersPool.address,
          amount: amount,
          pendingDeposit: tonstackerBalance?.stackingInfo.pendingDeposit ?? 0,
          pendingWithdraw:tonstackerBalance?.stackingInfo.pendingWithdraw ?? 0,
          readyWithdraw: tonstackerBalance?.stackingInfo.readyWithdraw ?? 0
        )
        tonstakersItem = BalanceListStakingItem(
          id: info.pool.toString(),
          info: info,
          poolInfo: tonstakersPool,
          currency: balance.currency,
          converted: tonstakersJetton.converted,
          price: tonstakersJetton.price
        )
      }
    }

    stakingItems = stackingBalance
      .sorted { left, right in
        left.amountConverted > right.amountConverted
      }
      .map { stakingItem in
        let stackingPool = stackingPools.first(where: { $0.address == stakingItem.stackingInfo.pool  })
        return BalanceListStakingItem(
          id: stakingItem.stackingInfo.pool.toString(),
          info: stakingItem.stackingInfo,
          poolInfo: stackingPool,
          currency: balance.currency,
          converted: stakingItem.amountConverted,
          price: stakingItem.price
        )
      }
    
    jettonItems = jettonsBalance
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
        return BalanceListJettonItem(
          id: $0.jettonBalance.item.jettonInfo.address.toString(),
          jetton: $0.jettonBalance.item,
          amount: $0.jettonBalance.quantity,
          fractionalDigits: $0.jettonBalance.item.jettonInfo.fractionDigits,
          tag: nil,
          currency: balance.currency,
          converted: $0.converted,
          price: $0.price,
          diff: $0.diff
        )
      }
    
    if let tonstakersItem {
      stakingItems.append(tonstakersItem)
    }
    
    let item = BalanceListItems(
      tonItem: tonItem,
      usdtItem: tonUSDTItem,
      jettonsItems: jettonItems,
      stakingItems: stakingItems
    )
    didUpdateItems?(item, isSecure)
  }
}

import Foundation
import KeeperCore
import BigInt

struct BalanceItems {
  let items: [BalanceItem]
}

enum BalanceItem {
  case ton(BalanceTonItemModel)
  case jetton(BalanceJettonItemModel)
  case staking(BalanceStakingItemModel)
}

struct BalanceTonItemModel {
  let id: String
  let title: String
  let amount: BigUInt
  let fractionalDigits: Int
  let currency: Currency
  let converted: Decimal
  let price: Decimal
  let diff: String?
}

struct BalanceJettonItemModel {
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

struct BalanceStakingItemModel {
  let id: String
  let info: AccountStackingInfo
  let poolInfo: StackingPoolInfo?
  let currency: Currency
  let converted: Decimal
  let price: Decimal
}

extension BalanceItems {
  init(balance: ConvertedBalance,
       stackingPools: [StackingPoolInfo]) {
    
    var jettonsBalance = balance.jettonsBalance
    var stackingBalance = balance.stackingBalance
    
    let tonModel = BalanceTonItemModel(
      id: TonInfo.symbol,
      title: TonInfo.symbol,
      amount: BigUInt(balance.tonBalance.tonBalance.amount),
      fractionalDigits: TonInfo.fractionDigits,
      currency: balance.currency,
      converted: balance.tonBalance.converted,
      price: balance.tonBalance.price,
      diff: balance.tonBalance.diff
    )

    let tonItem: BalanceItem = .ton(tonModel)
    
    var stakingItems = [BalanceItem]()
    var jettonItems = [BalanceItem]()
    
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
        let tonstakersItem = BalanceStakingItemModel(
          id: info.pool.toRaw(),
          info: info,
          poolInfo: tonstakersPool,
          currency: balance.currency,
          converted: tonstakersJetton.converted,
          price: tonstakersJetton.price
        )
        stakingItems.append(.staking(tonstakersItem))
      }
    }
    
    stakingItems.append(contentsOf: stackingBalance.map { stakingBalanceItem in
      let stackingPool = stackingPools.first(where: { $0.address == stakingBalanceItem.stackingInfo.pool  })
      return .staking(BalanceStakingItemModel(
        id: stakingBalanceItem.stackingInfo.pool.toRaw(),
        info: stakingBalanceItem.stackingInfo,
        poolInfo: stackingPool,
        currency: balance.currency,
        converted: stakingBalanceItem.amountConverted,
        price: stakingBalanceItem.price
      ))
    })
    
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
        return .jetton(BalanceJettonItemModel(
          id: $0.jettonBalance.item.jettonInfo.address.toRaw(),
          jetton: $0.jettonBalance.item,
          amount: $0.jettonBalance.quantity,
          fractionalDigits: $0.jettonBalance.item.jettonInfo.fractionDigits,
          tag: nil,
          currency: balance.currency,
          converted: $0.converted,
          price: $0.price,
          diff: $0.diff
        ))
      }
    
    self.items = stakingItems + jettonItems + [tonItem]
  }
}

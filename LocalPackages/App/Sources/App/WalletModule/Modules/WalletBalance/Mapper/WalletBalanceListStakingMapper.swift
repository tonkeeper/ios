import Foundation
import TKUIKit
import TKLocalize
import KeeperCore
import BigInt

struct WalletBalanceListStakingMapper {
  private let dateComponentsFormatter: DateComponentsFormatter = {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.hour, .minute, .second]
    formatter.zeroFormattingBehavior = .pad
    return formatter
  }()
  
  private let amountFormatter: AmountFormatter
  private let balanceItemMapper: BalanceItemMapper
  
  init(amountFormatter: AmountFormatter, 
       balanceItemMapper: BalanceItemMapper) {
    self.amountFormatter = amountFormatter
    self.balanceItemMapper = balanceItemMapper
  }
  
  func mapStakingItem(_ item: ProcessedBalanceStakingItem,
                      isSecure: Bool,
                      isPinned: Bool,
                      stakingCollectHandler: (() -> Void)?) -> WalletBalanceListCell.Configuration {
    let commentConfiguration = { () -> TKCommentView.Model? in
      guard let comment = mapStakingItemComment(item, isSecure: isSecure, stakingCollectHandler: stakingCollectHandler) else {
        return nil
      }
      return TKCommentView.Model(comment: comment.text, tapClosure: comment.tapHandler)
    }
    
    return WalletBalanceListCell.Configuration(
      walletBalanceListCellContentViewConfiguration:
        WalletBalanceListCellContentView.Configuration(
          listItemContentViewConfiguration: balanceItemMapper.mapStakingItem(item, isSecure: isSecure, isPinned: isPinned),
          commentViewConfiguration: commentConfiguration()
        )
    )
  }
  
  private func mapStakingItemComment(_ item: ProcessedBalanceStakingItem,
                                     isSecure: Bool,
                                     stakingCollectHandler: (() -> Void)?) -> StakingComment? {
    let estimate = formatEstimate(item: item)
    
    if item.info.pendingDeposit > 0 {
      let amount: String = {
        if isSecure {
          return .secureModeValueShort
        } else {
          return amountFormatter.formatAmount(
            BigUInt(item.info.pendingDeposit),
            fractionDigits: TonInfo.fractionDigits,
            maximumFractionDigits: 4)
        }
      }()
      let comment = "\(TKLocales.BalanceList.StakingItem.Comment.staked(amount))\(estimate)"
      return StakingComment(text: comment, tapHandler: nil)
    }
    
    if item.info.pendingWithdraw > 0 {
      let amount: String = {
        if isSecure {
          return .secureModeValueShort
        } else {
          return amountFormatter.formatAmount(
            BigUInt(item.info.pendingWithdraw),
            fractionDigits: TonInfo.fractionDigits,
            maximumFractionDigits: 4)
        }
      }()
      let comment = "\(TKLocales.BalanceList.StakingItem.Comment.unstaked(amount))\(estimate)"
      return StakingComment(text: comment, tapHandler: nil)
    }
    
    if item.info.readyWithdraw > 0 {
      let amount: String = {
        if isSecure {
          return .secureModeValueShort
        } else {
          return amountFormatter.formatAmount(
            BigUInt(item.info.readyWithdraw),
            fractionDigits: TonInfo.fractionDigits,
            maximumFractionDigits: 4)
        }
      }()
      
      let comment = TKLocales.BalanceList.StakingItem.Comment.ready(amount)
      return StakingComment(text: comment, tapHandler: stakingCollectHandler)
    }
    return nil
  }
  
  private func formatEstimate(item: ProcessedBalanceStakingItem) -> String {
    if item.poolInfo?.liquidJettonMaster == JettonMasterAddress.tonstakers {
      return " \(TKLocales.BalanceList.StakingItem.Comment.afterEndOfCycle)"
    }
    
    if let poolInfo = item.poolInfo,
       let formattedEstimatedTime = formatCycleEnd(timestamp: poolInfo.cycleEnd) {
      return "\n\(TKLocales.BalanceList.StakingItem.Comment.timeEstimate(formattedEstimatedTime))"
    }
    
    return ""
  }
  
  private func formatCycleEnd(timestamp: TimeInterval) -> String? {
    let now = Date()
    var estimateDate = Date(timeIntervalSince1970: timestamp)
    if estimateDate <= now {
      estimateDate = now
    }
    let components = Calendar.current.dateComponents(
      [.hour, .minute, .second], from: now,
      to: estimateDate
    )
    return dateComponentsFormatter.string(from: components)
  }
}

private struct StakingComment {
  let text: String
  let tapHandler: (() -> Void)?
}

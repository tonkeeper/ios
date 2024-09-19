import UIKit
import TKUIKit
import TKLocalize
import TKCore
import KeeperCore
import BigInt

struct WalletBalanceListMapper {
  
  let imageLoader = ImageLoader()
  
  private let dateComponentsFormatter: DateComponentsFormatter = {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.hour, .minute, .second]
    formatter.zeroFormattingBehavior = .pad
    return formatter
  }()
  
  private let amountFormatter: AmountFormatter
  private let balanceItemMapper: BalanceItemMapper
  private let rateConverter: RateConverter
  
  init(amountFormatter: AmountFormatter,
       balanceItemMapper: BalanceItemMapper,
       rateConverter: RateConverter) {
    self.amountFormatter = amountFormatter
    self.rateConverter = rateConverter
    self.balanceItemMapper = balanceItemMapper
  }
  
  func mapTonItem(_ item: ProcessedBalanceTonItem,
                  isSecure: Bool,
                  isPinned: Bool) -> WalletBalanceListCell.Configuration {
    return WalletBalanceListCell.Configuration(
      walletBalanceListCellContentViewConfiguration: WalletBalanceListCellContentView.Configuration(
        listItemContentViewConfiguration: balanceItemMapper.mapTonItem(item, isSecure: isSecure, isPinned: isPinned),
        commentViewConfiguration: nil
      )
    )
  }
  
  func mapJettonItem(_ item: ProcessedBalanceJettonItem,
                     isSecure: Bool,
                     isPinned: Bool) -> WalletBalanceListCell.Configuration {
    return WalletBalanceListCell.Configuration(
      walletBalanceListCellContentViewConfiguration: WalletBalanceListCellContentView.Configuration(
        listItemContentViewConfiguration: balanceItemMapper.mapJettonItem(item, isSecure: isSecure, isPinned: isPinned),
        commentViewConfiguration: nil
      )
    )
  }
  
  func mapStakingItem(_ item: ProcessedBalanceStakingItem,
                      isSecure: Bool,
                      isPinned: Bool,
                      stakingCollectHandler: (() -> Void)?) -> WalletBalanceListCell.Configuration {
    let commentConfiguration = { () -> TKCommentView.Model? in
      guard let comment = mapStakingItemComment(item, stakingCollectHandler: stakingCollectHandler) else {
        return nil
      }
      return TKCommentView.Model(comment: comment.text, tapClosure: comment.tapHandler)
    }
    
    return WalletBalanceListCell.Configuration(
      walletBalanceListCellContentViewConfiguration: WalletBalanceListCellContentView.Configuration(
        listItemContentViewConfiguration: balanceItemMapper.mapStakingItem(item, isSecure: isSecure, isPinned: isPinned),
        commentViewConfiguration: commentConfiguration()
      )
    )
  }
  
  private func mapStakingItemComment(_ item: ProcessedBalanceStakingItem,
                                     stakingCollectHandler: (() -> Void)?) -> Comment? {
    
    let estimate: String = {
      if let poolInfo = item.poolInfo,
         let formattedEstimatedTime = formatCycleEnd(timestamp: poolInfo.cycleEnd) {
        return "\n\(TKLocales.BalanceList.StakingItem.Comment.timeEstimate(formattedEstimatedTime))"
      }
      return ""
    }()
    
    if item.info.pendingDeposit > 0 {
      let amount = amountFormatter.formatAmount(
        BigUInt(item.info.pendingDeposit),
        fractionDigits: TonInfo.fractionDigits,
        maximumFractionDigits: 2)
      let comment = "\(TKLocales.BalanceList.StakingItem.Comment.staked(amount))\(estimate)"
      return Comment(text: comment, tapHandler: nil)
    }
    
    if item.info.pendingWithdraw > 0 {
      let amount = amountFormatter.formatAmount(
        BigUInt(item.info.pendingWithdraw),
        fractionDigits: TonInfo.fractionDigits,
        maximumFractionDigits: 2)
      let comment = "\(TKLocales.BalanceList.StakingItem.Comment.unstaked(amount))\(estimate)"
      return Comment(text: comment, tapHandler: nil)
    }
    
    if item.info.readyWithdraw > 0 {
      let amount = amountFormatter.formatAmount(
        BigUInt(item.info.readyWithdraw),
        fractionDigits: TonInfo.fractionDigits,
        maximumFractionDigits: 2)
      
      let comment = TKLocales.BalanceList.StakingItem.Comment.ready(amount)
      return Comment(text: comment, tapHandler: stakingCollectHandler)
    }
    return nil
  }
  
  func createTelegramChannelConfiguration() -> WalletBalanceListCell.Configuration {
    createSetupItem(
      text: TKLocales.WalletBalanceList.joinChannel,
      icon: .TKUIKit.Icons.Size28.telegram,
      iconColor: .Accent.blue
    )
  }
  
  func createNotificationsConfiguration() -> WalletBalanceListCell.Configuration {
    createSetupItem(
      text: TKLocales.WalletBalanceList.transactionNotifications,
      icon: .TKUIKit.Icons.Size28.bell,
      iconColor: .Accent.green
    )
  }
  
  func createBiometryConfiguration() -> WalletBalanceListCell.Configuration {
    let title: String
    let icon: UIImage
    
    let biometryProvider = BiometryProvider()
    let state = biometryProvider.getBiometryState(policy: .deviceOwnerAuthenticationWithBiometrics)
    switch state {
    case .success(let success):
      switch success {
      case .faceID:
        title = TKLocales.FinishSetup.setupBiometry(String.faceID)
        icon = .TKUIKit.Icons.Size28.faceId
      case .touchID:
        title = TKLocales.FinishSetup.setupBiometry(String.touchID)
        icon = .TKUIKit.Icons.Size28.faceId
      case .none:
        title = TKLocales.FinishSetup.biometryUnavailable
        icon = .TKUIKit.Icons.Size28.faceId
      }
    case .failure:
      title = TKLocales.FinishSetup.biometryUnavailable
      icon = .TKUIKit.Icons.Size28.faceId
    }

    return createSetupItem(
      text: title,
      icon: icon,
      iconColor: .Accent.green
    )
  }
  
  func createBackupConfiguration() -> WalletBalanceListCell.Configuration {
    createSetupItem(
      text: TKLocales.FinishSetup.backup,
      icon: .TKUIKit.Icons.Size28.key,
      iconColor: .Accent.orange
    )
  }
  
  private func createSetupItem(text: String,
                               icon: UIImage,
                               iconColor: UIColor) -> WalletBalanceListCell.Configuration {
    
    let title = text.withTextStyle(.body2, color: .Text.primary)
    
    return WalletBalanceListCell.Configuration(
      walletBalanceListCellContentViewConfiguration: WalletBalanceListCellContentView.Configuration(
        listItemContentViewConfiguration: TKListItemContentView.Configuration(
          iconViewConfiguration: TKListItemIconView.Configuration(
            content: .image(
              TKImageView.Model(
                image: .image(icon),
                tintColor: iconColor,
                size: .auto,
                corners: .circle
              )
            ),
            alignment: .top,
            cornerRadius: .iconCornerRadius,
            backgroundColor: iconColor.withAlphaComponent(0.12),
            size: .iconSize
          ),
          textContentViewConfiguration: TKListItemTextContentView.Configuration(
            titleViewConfiguration: TKListItemTitleView.Configuration(title: title, numberOfLines: 0)
          )
        )
      )
    )
  }
  
  func formatCycleEnd(timestamp: TimeInterval) -> String? {
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

private struct Comment {
  let text: String
  let tapHandler: (() -> Void)?
}

private extension CGSize {
  static let iconSize = CGSize(width: 44, height: 44)
}

private extension CGFloat {
  static let iconCornerRadius: CGFloat = 22
}

extension String {
  static let secureModeValue = "* * *"
  static let faceID = TKLocales.SettingsListSecurityConfigurator.faceId
  static let touchID = TKLocales.SettingsListSecurityConfigurator.touchId
}

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
                  selectionHandler: @escaping () -> Void) -> WalletBalanceListCell.Model {
    return WalletBalanceListCell.Model(
      listItemConfiguration: balanceItemMapper.mapTonItem(item, isSecure: isSecure),
      commentConfiguration: nil,
      selectionClosure: selectionHandler
    )
  }
  
  func mapJettonItem(_ item: ProcessedBalanceJettonItem,
                     isSecure: Bool,
                     selectionHandler: @escaping () -> Void) -> WalletBalanceListCell.Model {
    return WalletBalanceListCell.Model(
      listItemConfiguration: balanceItemMapper.mapJettonItem(item, isSecure: isSecure),
      commentConfiguration: nil,
      selectionClosure: selectionHandler
    )
  }
  
  func mapStakingItem(_ item: ProcessedBalanceStakingItem,
                      isSecure: Bool,
                      selectionHandler: @escaping () -> Void,
                      stakingCollectHandler: (() -> Void)?) -> WalletBalanceListCell.Model {
    let commentConfiguration = { () -> TKCommentView.Model? in
      guard let comment = mapStakingItemComment(item, stakingCollectHandler: stakingCollectHandler) else {
        return nil
      }
      return TKCommentView.Model(comment: comment.text, tapClosure: comment.tapHandler)
    }
    
    return WalletBalanceListCell.Model(
      listItemConfiguration: balanceItemMapper.mapStakingItem(item, isSecure: isSecure),
      commentConfiguration: commentConfiguration(),
      selectionClosure: selectionHandler
    )
  }
  
  private func mapStakingItemComment(_ item: ProcessedBalanceStakingItem,
                                     stakingCollectHandler: (() -> Void)?) -> Comment? {
    
    let estimate: String = {
      if let poolInfo = item.poolInfo,
         let formattedEstimatedTime = formatCycleEnd(timestamp: poolInfo.cycleEnd) {
        return "\n\(TKLocales.BalanceList.StakingItem.Comment.time_estimate(formattedEstimatedTime))"
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

  
  func mapSetupState(_ state: WalletBalanceSetupModel.State,
                     biometrySelectionHandler: @escaping () -> Void,
                     biometrySwitchHandler: @escaping (Bool) async -> Bool,
                     telegramChannelSelectionHandler: @escaping () -> Void,
                     backupSelectionHandler: @escaping () -> Void) -> [String: WalletBalanceListCell.Model] {
    switch state {
    case .none:
      return [:]
    case .setup(let setup):
      var items = [String: WalletBalanceListCell.Model]()
      items[WalletBalanceSetupItem.telegramChannel.rawValue] = createTelegramChannelItem(
        selectionHandler: telegramChannelSelectionHandler
      )
      if setup.isBiometryVisible {
        items[WalletBalanceSetupItem.biometry.rawValue] = createBiometryItem(
          selectionHandler: biometrySelectionHandler, 
          switchHandler: biometrySwitchHandler
        )
      }
      if setup.isBackupVisible {
        items[WalletBalanceSetupItem.backup.rawValue] = createBackupItem(
          selectionHandler: backupSelectionHandler
        )
      }
      return items
    }
  }
  
  private func createTelegramChannelItem(selectionHandler: @escaping () -> Void) -> WalletBalanceListCell.Model {
    createSetupItem(
      description: "Join Tonkeeper channel",
      icon: .TKUIKit.Icons.Size28.telegram,
      iconColor: .Accent.blue,
      accessory: .chevron,
      selectionHandler: selectionHandler
    )
  }
  
  private func createBiometryItem(selectionHandler: @escaping () -> Void,
                                  switchHandler: @escaping (Bool) async -> Bool) -> WalletBalanceListCell.Model {
    let title: String
    let icon: UIImage
    
    let biometryProvider = BiometryProvider()
    let state = biometryProvider.getBiometryState(policy: .deviceOwnerAuthenticationWithBiometrics)
    switch state {
    case .success(let success):
      switch success {
      case .faceID:
        title = TKLocales.FinishSetup.setup_biometry("Face ID")
        icon = .TKUIKit.Icons.Size28.faceId
      case .touchID:
        title = TKLocales.FinishSetup.setup_biometry("Touch ID")
        icon = .TKUIKit.Icons.Size28.faceId
      case .none:
        title = TKLocales.FinishSetup.biometry_unavailable
        icon = .TKUIKit.Icons.Size28.faceId
      }
    case .failure:
      title = TKLocales.FinishSetup.biometry_unavailable
      icon = .TKUIKit.Icons.Size28.faceId
    }
    
    let switchAccessoryConfiguration = TKUIListItemSwitchAccessoryView.Configuration(
      isOn: false,
      handler: switchHandler)
    
    return createSetupItem(
      description: title,
      icon: icon,
      iconColor: .Accent.green,
      accessory: .switchControl(switchAccessoryConfiguration),
      selectionHandler: selectionHandler
    )
  }
  
  private func createBackupItem(selectionHandler: @escaping () -> Void) -> WalletBalanceListCell.Model {
    createSetupItem(
      description: TKLocales.FinishSetup.backup,
      icon: .TKUIKit.Icons.Size28.key,
      iconColor: .Accent.orange,
      accessory: .chevron,
      selectionHandler: selectionHandler
    )
  }
  
  private func createSetupItem(description: String,
                               icon: UIImage,
                               iconColor: UIColor,
                               accessory: TKUIListItemAccessoryView.Configuration,
                               selectionHandler: @escaping () -> Void) -> WalletBalanceListCell.Model {
    let leftItemConfiguration = TKUIListItemContentLeftItem.Configuration(
      title: nil,
      tagViewModel: nil,
      subtitle: nil,
      description: description.withTextStyle(
        .body2,
        color: .Text.primary,
        alignment: .left,
        lineBreakMode: .byWordWrapping
      )
    )
    
    let contentConfiguration = TKUIListItemContentView.Configuration(
      leftItemConfiguration: leftItemConfiguration,
      rightItemConfiguration: nil
    )
    
    let iconConfiguration = TKUIListItemIconView.Configuration(
      iconConfiguration: .image(
        TKUIListItemImageIconView.Configuration(
          image: .image(icon),
          tintColor: iconColor,
          backgroundColor: iconColor.withAlphaComponent(0.12),
          size: .iconSize,
          cornerRadius: CGSize.iconSize.height/2
        )
      ),
      alignment: .center
    )
    
    let listItemConfiguration = TKUIListItemView.Configuration(
      iconConfiguration: iconConfiguration,
      contentConfiguration: contentConfiguration,
      accessoryConfiguration: accessory
    )
    
    return WalletBalanceListCell.Model(
      listItemConfiguration: listItemConfiguration,
      selectionClosure: selectionHandler
    )
  }
  
  func formatCycleEnd(timestamp: TimeInterval) -> String? {
    let estimateDate = Date(timeIntervalSince1970: timestamp)
    let components = Calendar.current.dateComponents(
      [.hour, .minute, .second], from: Date(),
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
}

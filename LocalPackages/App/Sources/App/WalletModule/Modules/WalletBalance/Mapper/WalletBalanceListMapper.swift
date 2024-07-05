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
  private let decimalAmountFormatter: DecimalAmountFormatter
  private let rateConverter: RateConverter
  
  init(amountFormatter: AmountFormatter,
       decimalAmountFormatter: DecimalAmountFormatter,
       rateConverter: RateConverter) {
    self.amountFormatter = amountFormatter
    self.decimalAmountFormatter = decimalAmountFormatter
    self.rateConverter = rateConverter
  }
  
  func mapTonItem(_ item: WalletBalanceBalanceModel.BalanceListTonItem,
                  isSecure: Bool,
                  selectionHandler: @escaping () -> Void) -> WalletBalanceListCell.Model {
    let amount = amountFormatter.formatAmount(
      item.amount,
      fractionDigits: item.fractionalDigits,
      maximumFractionDigits: 2
    )
    
    let converted = decimalAmountFormatter.format(
      amount: item.converted,
      maximumFractionDigits: 2,
      currency: item.currency
    )
    
    let price = decimalAmountFormatter.format(
      amount: item.price,
      currency: item.currency
    )
    let itemModel = ItemModel(
      title: item.title,
      tag: nil,
      image: .ton,
      price: price,
      rateDiff: item.diff,
      amount: amount,
      convertedAmount: converted,
      verification: .whitelist,
      comment: nil
    )
    
    return mapItemModel(itemModel,
                        isSecure: isSecure,
                        selectionHandler: selectionHandler)
  }
  
  func mapJettonItem(_ item: WalletBalanceBalanceModel.BalanceListJettonItem,
                     isSecure: Bool,
                     selectionHandler: @escaping () -> Void) -> WalletBalanceListCell.Model {
    let amount = amountFormatter.formatAmount(
      item.amount,
      fractionDigits: item.fractionalDigits,
      maximumFractionDigits: 2
    )
    
    let converted = decimalAmountFormatter.format(
      amount: item.converted,
      maximumFractionDigits: 2,
      currency: item.currency
    )
    
    let price = decimalAmountFormatter.format(
      amount: item.price,
      currency: item.currency
    )

    let verification: JettonInfo.Verification = {
      item.jetton.jettonInfo.verification
    }()
    
    let itemModel = ItemModel(
      title: item.jetton.jettonInfo.symbol ?? item.jetton.jettonInfo.name,
      tag: item.tag,
      image: .url(item.jetton.jettonInfo.imageURL),
      price: price,
      rateDiff: item.diff,
      amount: amount,
      convertedAmount: converted,
      verification: verification,
      comment: nil
    )
    
    return mapItemModel(itemModel,
                        isSecure: isSecure,
                        selectionHandler: selectionHandler)
  }
  
  func mapStakingItem(_ item: WalletBalanceBalanceModel.BalanceListStakingItem,
                      isSecure: Bool,
                      selectionHandler: @escaping () -> Void,
                      stakingCollectHandler: (() -> Void)?) -> WalletBalanceListCell.Model {
    let amount = amountFormatter.formatAmount(
      BigUInt(item.info.amount),
      fractionDigits: TonInfo.fractionDigits,
      maximumFractionDigits: 2
    )
    
    let converted = decimalAmountFormatter.format(
      amount: item.converted,
      maximumFractionDigits: 2,
      currency: item.currency
    )
    
    let price = item.poolInfo?.name ?? decimalAmountFormatter.format(
      amount: item.price,
      currency: item.currency
    )

    let itemModel = ItemModel(
      title: TKLocales.BalanceList.StakingItem.title,
      tag: nil,
      image: .ton,
      price: price,
      rateDiff: nil,
      amount: amount,
      convertedAmount: converted,
      verification: .whitelist,
      comment: mapStakingItemComment(item, stakingCollectHandler: stakingCollectHandler)
    )
    
    return mapItemModel(itemModel,
                        isSecure: isSecure,
                        selectionHandler: selectionHandler)
  }
  
  private func mapStakingItemComment(_ item: WalletBalanceBalanceModel.BalanceListStakingItem,
                                     stakingCollectHandler: (() -> Void)?) -> ItemModel.Comment? {
    
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
      return ItemModel.Comment(text: comment, tapHandler: nil)
    }
    
    if item.info.pendingWithdraw > 0 {
      let amount = amountFormatter.formatAmount(
        BigUInt(item.info.pendingWithdraw),
        fractionDigits: TonInfo.fractionDigits,
        maximumFractionDigits: 2)
      let comment = "\(TKLocales.BalanceList.StakingItem.Comment.unstaked(amount))\(estimate)"
      return ItemModel.Comment(text: comment, tapHandler: nil)
    }
    
    if item.info.readyWithdraw > 0 {
      let amount = amountFormatter.formatAmount(
        BigUInt(item.info.readyWithdraw),
        fractionDigits: TonInfo.fractionDigits,
        maximumFractionDigits: 2)
      
      let comment = TKLocales.BalanceList.StakingItem.Comment.ready(amount)
      return ItemModel.Comment(text: comment, tapHandler: stakingCollectHandler)
    }
    return nil
  }

  
  func mapSetupState(_ state: WalletBalanceSetupModel.State,
                     biometrySelectionHandler: @escaping () -> Void,
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
        items[WalletBalanceSetupItem.biometry.rawValue] = createBiometryItem(selectionHandler: biometrySelectionHandler)
      }
      if setup.isBackupVisible {
        items[WalletBalanceSetupItem.backup.rawValue] = createBackupItem(
          selectionHandler: backupSelectionHandler
        )
      }
      return items
    }
  }

  private func mapItemModel(_ itemModel: ItemModel,
                            isSecure: Bool,
                            selectionHandler: @escaping () -> Void) -> WalletBalanceListCell.Model {
    let title = itemModel.title.withTextStyle(
      .label1,
      color: .Text.primary,
      alignment: .left,
      lineBreakMode: .byTruncatingTail
    )
    
    let subtitle = NSMutableAttributedString()
    
    switch itemModel.verification {
    case .none:
      subtitle.append(TKLocales.Token.unverified.withTextStyle(.body2, color: .Accent.orange, alignment: .left, lineBreakMode: .byTruncatingTail))
    case .whitelist:
      if let price = itemModel.price?.withTextStyle(
        .body2,
        color: .Text.secondary,
        alignment: .left,
        lineBreakMode: .byTruncatingTail
      ) {
        subtitle.append(price)
        subtitle.append(" ".withTextStyle(.body2, color: .Text.secondary))
      }
      
      if let diff = itemModel.rateDiff {
        let color: UIColor
        if diff.hasPrefix("-") || diff.hasPrefix("−") {
          color = .Accent.red
        } else if diff.hasPrefix("+") {
          color = .Accent.green
        } else {
          color = .Text.tertiary
        }
        subtitle.append(diff.withTextStyle(.body2, color: color, alignment: .left))
      }
    case .blacklist:
      subtitle.append(TKLocales.Token.unverified.withTextStyle(.body2, color: .Accent.orange, alignment: .left, lineBreakMode: .byTruncatingTail))
    }
    
    let amount = isSecure ? String.secureModeValue : itemModel.amount
    let convertedAmount = isSecure ? String.secureModeValue : itemModel.convertedAmount
    
    let value = amount?.withTextStyle(
      .label1,
      color: .Text.primary,
      alignment: .right,
      lineBreakMode: .byTruncatingTail
    )
    let valueSubtitle = convertedAmount?.withTextStyle(
      .body2,
      color: .Text.secondary,
      alignment: .right,
      lineBreakMode: .byTruncatingTail
    )
    
    let iconConfigurationImage: TKUIListItemImageIconView.Configuration.Image
    switch itemModel.image {
    case .ton:
      iconConfigurationImage = .image(.TKCore.Icons.Size44.tonLogo)
    case .url(let url):
      iconConfigurationImage = .asyncImage(
        url,
        TKCore.ImageDownloadTask(
          closure: {
            [imageLoader] imageView,
            size,
            cornerRadius in
            return imageLoader.loadImage(
              url: url,
              imageView: imageView,
              size: size,
              cornerRadius: cornerRadius
            )
          }
        )
      )
    }
    
    let iconConfiguration = TKUIListItemIconView.Configuration(
      iconConfiguration: .image(
        TKUIListItemImageIconView.Configuration(
          image: iconConfigurationImage,
          tintColor: .Icon.primary,
          backgroundColor: .Background.contentTint,
          size: .iconSize,
          cornerRadius: CGSize.iconSize.height/2
        )
      ),
      alignment: .center
    )
    
    var tagViewModel: TKUITagView.Configuration?
    if let tag = itemModel.tag {
      tagViewModel = TKUITagView.Configuration(
        text: tag,
        textColor: .Text.secondary,
        backgroundColor: .Background.contentTint
      )
    }
    
    let listItemConfiguration = TKUIListItemView.Configuration(
      iconConfiguration: iconConfiguration,
      contentConfiguration: TKUIListItemContentView.Configuration(
        leftItemConfiguration: TKUIListItemContentLeftItem.Configuration(
          title: title,
          tagViewModel: tagViewModel,
          subtitle: subtitle,
          description: nil
        ),
        rightItemConfiguration: TKUIListItemContentRightItem.Configuration(
          value: value,
          subtitle: valueSubtitle,
          description: nil
        )
      ),
      accessoryConfiguration: .none
    )
    
    var commentConfiguration: TKCommentView.Model?
    if let comment = itemModel.comment {
      commentConfiguration = TKCommentView.Model(comment: comment.text, tapClosure: comment.tapHandler)
    }
    
    return WalletBalanceListCell.Model(
      listItemConfiguration: listItemConfiguration,
      commentConfiguration: commentConfiguration,
      selectionClosure: selectionHandler
    )
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
  
  private func createBiometryItem(selectionHandler: @escaping () -> Void) -> WalletBalanceListCell.Model {
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
      handler: {
        selectionHandler()
        return $0
      })
    
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

private extension TKUIListItemAccessoryView.Configuration {
  static var chevron: TKUIListItemAccessoryView.Configuration {
    .image(
      TKUIListItemImageAccessoryView.Configuration(
        image: .TKUIKit.Icons.Size16.chevronRight,
        tintColor: .Text.tertiary,
        padding: .zero
      )
    )
  }
}

private struct ItemModel {
  struct Comment {
    let text: String
    let tapHandler: (() -> Void)?
  }
  
  let title: String
  let tag: String?
  let image: TokenImage
  let price: String?
  let rateDiff: String?
  let amount: String?
  let convertedAmount: String?
  let verification: JettonInfo.Verification
  let comment: Comment?
}

private extension CGSize {
  static let iconSize = CGSize(width: 44, height: 44)
}

private extension CGFloat {
  static let iconCornerRadius: CGFloat = 22
}

private extension String {
  static let secureModeValue = "* * *"
}

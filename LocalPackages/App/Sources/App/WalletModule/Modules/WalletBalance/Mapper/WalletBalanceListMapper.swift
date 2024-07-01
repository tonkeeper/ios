import UIKit
import TKUIKit
import TKLocalize
import TKCore
import KeeperCore
import BigInt

struct WalletBalanceListMapper {
  
  let imageLoader = ImageLoader()
  
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
  
  func mapItem(_ item: BalanceListModel.BalanceListItem,
               selectionHandler: @escaping () -> Void) -> TKUIListItemCell.Configuration {
    let amount = amountFormatter.formatAmount(
      item.amount,
      fractionDigits: TonInfo.fractionDigits,
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
      switch item.type {
      case .ton:
        return .whitelist
      case .jetton(let jettonItem):
        return jettonItem.jettonInfo.verification
      }
    }()
    
    let image: TokenImage = {
      switch item.image {
      case .ton:
        return .ton
      case .url(let url):
        return .url(url)
      }
    }()
    
    let itemModel = ItemModel(
      title: item.title,
      tag: item.tag,
      image: image,
      price: price,
      rateDiff: item.diff,
      amount: amount,
      convertedAmount: converted,
      verification: verification
    )
    
    return mapItemModel(itemModel, selectionHandler: selectionHandler)
  }
  
  func mapSetupState(_ state: WalletBalanceSetupModel.State,
                     biometrySelectionHandler: @escaping () -> Void,
                     telegramChannelSelectionHandler: @escaping () -> Void,
                     backupSelectionHandler: @escaping () -> Void) -> [WalletBalanceItem: TKUIListItemCell.Configuration] {
    switch state {
    case .none:
      return [:]
    case .setup(let setup):
      var items = [WalletBalanceItem: TKUIListItemCell.Configuration]()
      items[WalletBalanceItem(id: WalletBalanceSetupItem.telegramChannel.rawValue)] = createTelegramChannelItem(
        selectionHandler: telegramChannelSelectionHandler
      )
      if setup.isBiometryVisible {
        items[WalletBalanceItem(id: WalletBalanceSetupItem.biometry.rawValue)] = createBiometryItem(selectionHandler: biometrySelectionHandler)
      }
      if setup.isBackupVisible {
        items[WalletBalanceItem(id: WalletBalanceSetupItem.backup.rawValue)] = createBackupItem(
          selectionHandler: backupSelectionHandler
        )
      }
      return items
    }
  }

  private func mapItemModel(_ itemModel: ItemModel,
                            selectionHandler: @escaping () -> Void) -> TKUIListItemCell.Configuration {
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
    
    let value = itemModel.amount?.withTextStyle(
      .label1,
      color: .Text.primary,
      alignment: .right,
      lineBreakMode: .byTruncatingTail
    )
    let valueSubtitle = itemModel.convertedAmount?.withTextStyle(
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
    
    return TKUIListItemCell.Configuration(
      id: "",
      listItemConfiguration: listItemConfiguration,
      selectionClosure: selectionHandler
    )
  }
  
  private func createTelegramChannelItem(selectionHandler: @escaping () -> Void) -> TKUIListItemCell.Configuration {
    createSetupItem(
      description: "Join Tonkeeper channel",
      icon: .TKUIKit.Icons.Size28.telegram,
      iconColor: .Accent.blue,
      accessory: .chevron,
      selectionHandler: selectionHandler
    )
  }
  
  private func createBiometryItem(selectionHandler: @escaping () -> Void) -> TKUIListItemCell.Configuration {
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
  
  private func createBackupItem(selectionHandler: @escaping () -> Void) -> TKUIListItemCell.Configuration {
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
                               selectionHandler: @escaping () -> Void) -> TKUIListItemCell.Configuration {
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
    
    return TKUIListItemCell.Configuration(
      id: "",
      listItemConfiguration: listItemConfiguration,
      selectionClosure: selectionHandler
    )
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
  public let title: String
  public let tag: String?
  public let image: TokenImage
  public let price: String?
  public let rateDiff: String?
  public let amount: String?
  public let convertedAmount: String?
  public let verification: JettonInfo.Verification
}

private extension CGSize {
  static let iconSize = CGSize(width: 44, height: 44)
}

private extension CGFloat {
  static let iconCornerRadius: CGFloat = 22
}


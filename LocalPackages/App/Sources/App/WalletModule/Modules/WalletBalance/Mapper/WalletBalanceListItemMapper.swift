import UIKit
import TKUIKit
import TKCore
import KeeperCore
import TKLocalize

struct WalletBalanceListItemMapper {
  
  let imageLoader = ImageLoader()
  
  func mapBalanceItem(_ item: WalletBalanceItemsModel.Item, selectionClosure: @escaping () -> Void) -> TKUIListItemCell.Configuration {
    let id: String
    switch item.token {
    case .ton:
      id = "ton"
    case .jetton(let jettonItem):
      id = jettonItem.jettonInfo.address.toRaw()
    }
    
    let titleString: String
    
    switch item.stakingInfo {
    case .none:
      titleString = item.title
    case .pool:
      titleString = .stakeditemTitle
    }
    
    let title = titleString.withTextStyle(
      .label1,
      color: .Text.primary,
      alignment: .left,
      lineBreakMode: .byTruncatingTail
    )
    
    let subtitle = NSMutableAttributedString()
    switch item.stakingInfo {
    case .none:
      switch item.verification {
      case .none:
        subtitle.append(TKLocales.Token.unverified.withTextStyle(.body2, color: .Accent.orange, alignment: .left, lineBreakMode: .byTruncatingTail))
      case .whitelist:
        if let price = item.price?.withTextStyle(
          .body2,
          color: .Text.secondary,
          alignment: .left,
          lineBreakMode: .byTruncatingTail
        ) {
          subtitle.append(price)
          subtitle.append(" ".withTextStyle(.body2, color: .Text.secondary))
        }
        
        if let diff = item.rateDiff {
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
      
    case .pool(let stakingPoolItem):
      subtitle.append(
        stakingPoolItem.name.withTextStyle(
          .body2,
          color: .Text.secondary,
          alignment: .left,
          lineBreakMode: .byTruncatingTail
        )
      )
    }
    
    let value = item.amount?.withTextStyle(
      .label1,
      color: .Text.primary,
      alignment: .right,
      lineBreakMode: .byTruncatingTail
    )
    let valueSubtitle = item.convertedAmount?.withTextStyle(
      .body2,
      color: .Text.secondary,
      alignment: .right,
      lineBreakMode: .byTruncatingTail
    )
    
    let primaryIconConfigurationImage: TKUIListItemImageIconView.Configuration.Image
    switch item.image {
    case .ton:
      primaryIconConfigurationImage = .image(.TKCore.Icons.Size44.tonLogo)
    case .url(let url):
      primaryIconConfigurationImage = .asyncImage(
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
    
    let iconConfiguration: TKUIListItemIconView.Configuration
    switch item.stakingInfo {
    case .none:
      iconConfiguration = .init(
        iconConfiguration: .image(
          TKUIListItemImageIconView.Configuration(
            image: primaryIconConfigurationImage,
            tintColor: .Icon.primary,
            backgroundColor: .Background.contentTint,
            size: .iconSize,
            cornerRadius: CGSize.iconSize.height/2
          )
        ),
        alignment: .center
      )
    case .pool(let stakingPoolItem):
      let badgeImage = TKUIListItemImageIconView.Configuration.Image.image(stakingPoolItem.poolType.image)
      let badgeIconConfiguration = TKUIListItemImageIconView.Configuration(
        image: badgeImage,
        tintColor: .Icon.primary,
        backgroundColor: .Background.contentTint,
        size: .badgeIconSize,
        cornerRadius: CGSize.badgeIconSize.width/2,
        borderWidth: .badgeBorderWidth,
        borderColor: .Background.content,
        contentMode: .scaleAspectFill
      )
      
      iconConfiguration = .init(
        iconConfiguration: .imageWithBadge(
          TKUIListItemImageIconView.Configuration(
            image: .image(.TKCore.Icons.Size44.tonLogo),
            tintColor: .Icon.primary,
            backgroundColor: .Background.contentTint,
            size: .iconSize,
            cornerRadius: CGSize.iconSize.height/2
          ),
          badgeIconConfiguration
        ),
        alignment: .center
      )
    }
    
    let listItemConfiguration = TKUIListItemView.Configuration(
      iconConfiguration: iconConfiguration,
      contentConfiguration: TKUIListItemContentView.Configuration(
        leftItemConfiguration: TKUIListItemContentLeftItem.Configuration(
          title: title,
          tagViewModel: nil,
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
      id: id,
      listItemConfiguration: listItemConfiguration,
      selectionClosure: selectionClosure
    )
  }
  
  func mapFinishSetup(model: WalletBalanceSetupModel,
                      biometryAuthentificator: BiometryAuthentificator,
                      backupHandler: @escaping () -> Void,
                      biometryHandler: @escaping (Bool) async -> Bool) -> [TKUIListItemCell.Configuration] {
    var items = [TKUIListItemCell.Configuration]()
    if !model.didBackup {
      items.append(createBackupItem(selectionClosure: backupHandler))
    }
    if model.biometry.isRequired {
      items.append(
        createBiometryItem(
          biometry: model.biometry,
          biometryAuthentificator: biometryAuthentificator,
          biometryHandler: biometryHandler
        )
      )
    }
    
    return items
  }
  
  func createBackupItem(selectionClosure: @escaping () -> Void) -> TKUIListItemCell.Configuration {
    
    let leftItemConfiguration = TKUIListItemContentLeftItem.Configuration(
      title: nil,
      tagViewModel: nil,
      subtitle: nil,
      description: TKLocales.FinishSetup.backup
        .withTextStyle(
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
    
    let listItemConfiguration = TKUIListItemView.Configuration(
      iconConfiguration: TKUIListItemIconView.Configuration(
        iconConfiguration: .image(
          TKUIListItemImageIconView.Configuration(
            image: .image(.TKUIKit.Icons.Size28.key),
            tintColor: .Icon.primary,
            backgroundColor: .Background.contentTint,
            size: .iconSize,
            cornerRadius: CGSize.iconSize.height/2
          )
        ),
        alignment: .center
      ),
      contentConfiguration: contentConfiguration,
      accessoryConfiguration: .image(
        .init(
          image: .TKUIKit.Icons.Size16.chevronRight,
          tintColor: .Text.tertiary,
          padding: .zero
        )
      )
    )
    
    return TKUIListItemCell.Configuration(
      id: .backupItemIdentifier,
      listItemConfiguration: listItemConfiguration,
      isHighlightable: true,
      selectionClosure: selectionClosure
    )
  }
  
  func createBiometryItem(
    biometry: WalletBalanceSetupModel.Biometry,
    biometryAuthentificator: BiometryAuthentificator,
    biometryHandler: @escaping (Bool) async -> Bool
  ) -> TKUIListItemCell.Configuration {
    
    let switchAccessoryConfiguration: TKUIListItemSwitchAccessoryView.Configuration = {
      let isOn: Bool
      let isEnabled: Bool
      
      let result = biometryAuthentificator.canEvaluate(policy: .deviceOwnerAuthenticationWithBiometrics)
      switch result {
      case .success:
        isOn = biometry.isBiometryEnabled
        isEnabled = true
      case .failure:
        isOn = false
        isEnabled = false
      }
      return TKUIListItemSwitchAccessoryView.Configuration(
        isOn: isOn) { isOn in
          return await biometryHandler(isOn)
        }
    }()

    let title: String
    let image: UIImage
    switch biometryAuthentificator.biometryType {
    case .touchID:
      title = TKLocales.FinishSetup.setup_biometry("Touch ID")
      image = .TKUIKit.Icons.Size28.faceId
    case .faceID:
      title = TKLocales.FinishSetup.setup_biometry("Face ID")
      image = .TKUIKit.Icons.Size28.faceId
    default:
      title = TKLocales.FinishSetup.biometry_unavailable
      image = .TKUIKit.Icons.Size28.faceId
    }
    
    let leftItemConfiguration = TKUIListItemContentLeftItem.Configuration(
      title: nil,
      tagViewModel: nil,
      subtitle: nil,
      description: title.withTextStyle(
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
          image: .image(image),
          tintColor: .Icon.primary,
          backgroundColor: .Background.contentTint,
          size: .iconSize,
          cornerRadius: CGSize.iconSize.height/2
        )
      ),
      alignment: .center
    )
    
    let listItemConfiguration = TKUIListItemView.Configuration(
      iconConfiguration: iconConfiguration,
      contentConfiguration: contentConfiguration,
      accessoryConfiguration: .switchControl(switchAccessoryConfiguration)
    )
    
    return TKUIListItemCell.Configuration(
      id: .biometryItemIdentifier,
      listItemConfiguration: listItemConfiguration,
      isHighlightable: false,
      selectionClosure: nil
    )
  }
}

private extension CGSize {
  static let iconSize = CGSize(width: 44, height: 44)
  static let badgeIconSize = CGSize(width: 18, height: 18)
}

private extension CGFloat {
  static let badgeBorderWidth: CGFloat = 2
}

private extension String {
  static let backupItemIdentifier = "BackupItem"
  static let biometryItemIdentifier = "BiometryItem"
  static let stakeditemTitle = "Staked"
}


import UIKit
import TKUIKit
import TKCore
import KeeperCore

struct WalletBalanceListItemMapper {
  
  let imageLoader = ImageLoader()
  
  func mapBalanceItems(_ item: WalletBalanceModel.Item,
                       selectionHandler: @escaping () -> Void) -> WalletBalanceBalanceItemCell.Model {
    
    let subtitle = NSMutableAttributedString()
    
    switch item.verification {
    case .none:
      subtitle.append("Unverified Token".withTextStyle(.body2, color: .Accent.orange, alignment: .left, lineBreakMode: .byTruncatingTail))
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
        if diff.hasPrefix("-") {
          color = .Accent.red
        } else {
          color = .Accent.green
        }
        subtitle.append(diff.withTextStyle(.body2, color: color, alignment: .left))
      }
    case .blacklist:
      subtitle.append("Unverified Token".withTextStyle(.body2, color: .Accent.orange, alignment: .left, lineBreakMode: .byTruncatingTail))
    }
    
    let contentViewModel = TKListItemContentStackView.Model(
      titleSubtitleModel: TKListItemTitleSubtitleView.Model(
        title: item.title.withTextStyle(.label1, color: .white, alignment: .left, lineBreakMode: .byTruncatingTail),
        subtitle: subtitle
      ),
      description: nil
    )

    let rightContentViewModel = TKListItemContentStackView.Model(
      titleSubtitleModel: TKListItemTitleSubtitleView.Model(
        title: item.amount?.withTextStyle(.label1, color: .white, alignment: .right, lineBreakMode: .byTruncatingTail),
        subtitle: item.convertedAmount?.withTextStyle(.body2, color: .Text.secondary, alignment: .right, lineBreakMode: .byTruncatingTail)
      ),
      description: nil
    )
    
    let contentModel = TKListItemContentView.Model(
      leftContentStackViewModel: contentViewModel,
      rightContentStackViewModel: rightContentViewModel
    )
    
    let image: TKListItemIconImageView.Model.Image
    switch item.image {
    case .ton:
      image = .image(.TKCore.Icons.Size44.tonLogo)
    case .url(let url):
      image = .asyncImage(
        TKCore.ImageDownloadTask(
          closure: {
            [imageLoader] imageView,
            size,
            cornerRadius in
            return imageLoader.loadImage(url: url, imageView: imageView, size: size, cornerRadius: cornerRadius)
          }
        )
      )
    }
    
    let iconModel = TKListItemIconImageView.Model(
      image: image,
      tintColor: .clear,
      backgroundColor: .clear,
      size: CGSize(width: 44, height: 44)
    )

    let cellModel = WalletBalanceBalanceItemCell.Model(
      identifier: item.identifier,
      isSelectable: false,
      selectionHandler: selectionHandler,
      cellContentModel: WalletBalanceBalanceItemCellContentView.Model(
        iconModel: iconModel,
        contentModel: contentModel
      )
    )
    return cellModel
  }
  
  func mapFinishSetup(model: WalletBalanceSetupModel,
                      biometryAuthentificator: BiometryAuthentificator,
                      backupHandler: @escaping () -> Void,
                      biometryHandler: @escaping (Bool) async -> Bool) -> [AnyHashable] {
    var items = [AnyHashable]()
    if !model.didBackup {
      items.append(createBackupItem(backupHandler: backupHandler))
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
  
  func mapFinishSetupSectionHeaderModel(model: WalletBalanceSetupModel) -> WalletBalanceCollectionController.SectionHeaderView.Model {
    let title = "Finish setting up"
    var buttonContent: TKButton.Configuration.Content?
    if model.isFinishSetupAvailable {
      buttonContent = TKButton.Configuration.Content(title: .plainString("Done"))
    }
    return WalletBalanceCollectionController.SectionHeaderView.Model(title: title, buttonContent: buttonContent)
  }
  
  func createBackupItem(backupHandler: @escaping () -> Void) -> WalletBalanceSetupPlainItemCell.Model {
    WalletBalanceSetupPlainItemCell.Model(
      identifier: .backupItemIdentifier,
      accessoryType: .disclosureIndicator,
      selectionHandler: {
        backupHandler()
      },
      cellContentModel: WalletBalanceSetupPlainItemCellContentView.Model(
        iconModel: TKListItemIconImageView.Model(
          image: .image(.TKUIKit.Icons.Size28.key),
          tintColor: .Icon.primary,
          backgroundColor: .Background.contentTint,
          size: .iconSize
        ),
        contentModel: WalletBalanceSetupContentView.Model(title: .backupDescription)
      )
    )
  }
  
  func createBiometryItem(
    biometry: WalletBalanceSetupModel.Biometry,
    biometryAuthentificator: BiometryAuthentificator,
    biometryHandler: @escaping (Bool) async -> Bool
  ) -> WalletBalanceSetupSwitchItemCell.Model {
    
      let switchModel: TKListItemSwitchView.Model = {
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
        return TKListItemSwitchView.Model(
          isOn: isOn,
          isEnabled: isEnabled,
          action: { isOn in
            return await biometryHandler(isOn)
          }
        )
      }()
    
      let title: String
      switch biometryAuthentificator.biometryType {
      case .touchID:
        title = .use + " " + .touchId + " " + .approveTransactions
      case .faceID:
        title = .use + " " + .faceId + " " + .approveTransactions
      default:
        title = .biometryUnavailable
      }
    
    
    return WalletBalanceSetupSwitchItemCell.Model(
      identifier: .biometryItemIdentifier,
      isHighlightable: false,
      cellContentModel: WalletBalanceSetupSwitchItemCellContentView.Model(
        iconModel: TKListItemIconImageView.Model(
          image: .image(.TKUIKit.Icons.Size28.faceId),
          tintColor: .Icon.primary,
          backgroundColor: .Background.contentTint,
          size: .iconSize
        ),
        contentModel: WalletBalanceSetupContentView.Model(title: title),
        valueModel: switchModel
      )
    )
  }
}

private extension CGSize {
  static let iconSize = CGSize(width: 44, height: 44)
}

private extension CGFloat {
  static let iconCornerRadius: CGFloat = 22
}

private extension String {
  static let backupItemIdentifier = "BackupItem"
  static let backupDescription = "Back up the wallet recovery phrase"
  static let biometryItemIdentifier = "BiometryItem"
  static let use = "Use"
  static let faceId = "Face ID"
  static let touchId = "Touch ID"
  static let approveTransactions = "to approve transactions"
  static let biometryUnavailable = "Biometry unavailable"
}


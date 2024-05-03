import UIKit
import TKUIKit

protocol SettingsModuleOutput: AnyObject {
  var didTapChangePassword: (() -> Void)? { get set }
}

protocol SettingsViewModel: AnyObject {
  var titleUpdate: ((String) -> Void)? { get set }
  var itemsListUpdate: ((NSDiffableDataSourceSnapshot<SettingsSection, AnyHashable>) -> Void)? { get set }
  
  func viewDidLoad()
}

final class SettingsViewModelImplementation: SettingsViewModel, SettingsModuleOutput {
  
  // MARK: - SettingsModuleOutput
  
  var didTapChangePassword: (() -> Void)?
  
  // MARK: - SettingsViewModel
  
  var titleUpdate: ((String) -> Void)?
  var itemsListUpdate: ((NSDiffableDataSourceSnapshot<SettingsSection, AnyHashable>) -> Void)?
  
  func viewDidLoad() {
    titleUpdate?("Settings")
    
    updateList()
  }
}

private extension SettingsViewModelImplementation {
  func updateList() {
    var snapshot = NSDiffableDataSourceSnapshot<SettingsSection, AnyHashable>()
    let sections = createSections()
    snapshot.appendSections(sections)
    for section in sections {
      snapshot.appendItems(section.items, toSection: section)
    }
    
    itemsListUpdate?(snapshot)
  }
  
  func createSections() -> [SettingsSection] {
    return [
      createFirstSection(),
      createSecondSection(),
      createFooterSection()
    ]
  }
  
  func createFirstSection() -> SettingsSection {
    SettingsSection(
      items: [
        createListItem(id: "ChangePasswordIdentifier",
                       title: "Change Password",
                       image: .TKUIKit.Icons.Size28.lock,
                       tintColor: .Accent.blue,
                       action: { [weak self] in
                         self?.didTapChangePassword?()
                       })
      ]
    )
  }
  
  func createSecondSection() -> SettingsSection {
    SettingsSection(
      items: [
        createListItem(id: "SupportIdentifier",
                       title: "Support",
                       image: .TKUIKit.Icons.Size28.messageBubble,
                       tintColor: .Icon.secondary,
                       action: {
                         
                       }),
        createListItem(id: "LegalIdentifier",
                       title: "Legal",
                       image: .TKUIKit.Icons.Size28.messageBubble,
                       tintColor: .Icon.secondary,
                       action: {
                         
                       })
      ]
    )
  }
  
  func createFooterSection() -> SettingsSection {
    SettingsSection(items: [
      SettingsListFooterCell.Model(top: "Signer", bottom: "Version 1.0")
    ])
  }
  
//  func createQRCodeSection() -> KeyDetailsSection {
//    KeyDetailsSection(
//      type: .qrCode,
//      items: [
//        createListItem(id: .qrCodeDescriptionItemIdentifier,
//                       title: "Export to another device",
//                       subtitle: "Open Tonkeeper » Import Existing Wallet » Pair Tonsign",
//                       image: nil,
//                       tintColor: .clear,
//                       action: { [weak self] in
//                         self?.sameDeviceLinkAction()
//        }),
//        KeyDetailsQRCodeCell.Model(image: qrCodeImage)
//      ]
//    )
//  }
//  
//  func createDeviceLinkSection() -> KeyDetailsSection {
//    KeyDetailsSection(
//      type: .deviceLink,
//      items: [
//        createListItem(id: .linkToDeviceItemIdentifier,
//                       title: "Link to Tonkeeper on this device",
//                       subtitle: "Tonkeeper must be installed",
//                       image: .TKUIKit.Icons.Size16.chevronRight,
//                       tintColor: .Icon.tertiary,
//                       action: { [weak self] in
//                         self?.sameDeviceLinkAction()
//        })
//      ]
//    )
//  }
//  
//  func createWebLinkSection() -> KeyDetailsSection {
//    KeyDetailsSection(
//      type: .webLink,
//      items: [
//        createListItem(id: .linkToWebItemIdentifier,
//                       title: "Link to Tonkeeper Web",
//                       subtitle: "wallet.tonkeeper.com",
//                       image: .TKUIKit.Icons.Size16.chevronRight,
//                       tintColor: .Icon.tertiary,
//                       action: { [weak self] in
//                         self?.webLinkAction()
//        })
//      ]
//    )
//  }
//  
//  func createActionsSection() -> KeyDetailsSection {
//    KeyDetailsSection(
//      type: .actions,
//      items: [
//        createListItem(id: .nameItemIdentifier,
//                       title: "Name",
//                       subtitle: keyDetailsController.walletKey.name,
//                       image: .TKUIKit.Icons.Size28.pencil,
//                       tintColor: .Accent.blue,
//                       action: { [weak self] in
//                         self?.didTapEdit?()
//        }),
//        createListItem(id: .hexItemIdentifier,
//                       title: "Hex Address",
//                       subtitle: keyDetailsController.walletKey.publicKeyShortHexString,
//                       image: .TKUIKit.Icons.Size28.copy,
//                       tintColor: .Accent.blue,
//                       action: { [weak self] in
//                         self?.didCopied?()
//        }),
//        createListItem(id: .recoveryPhraseItemIdentifier,
//                       title: "Recovery Phrase",
//                       image: .TKUIKit.Icons.Size28.key,
//                       tintColor: .Accent.blue,
//                       action: { [weak self] in
//                         self?.didTapOpenRecoveryPhrase?()
//        })
//      ]
//    )
//  }
//  
//  func createDeleteSection() -> KeyDetailsSection {
//    KeyDetailsSection(
//      type: .delete,
//      items: [
//        createListItem(id: .deleteItemIdentifier,
//                       title: "Delete Key",
//                       image: .TKUIKit.Icons.Size28.trashBin,
//                       tintColor: .Accent.blue,
//                       action: { [weak self] in
//                         self?.didSelectDelete?()
//        })
//      ]
//    )
//  }
  
  func createListItem(id: String,
                      title: String,
                      subtitle: String? = nil,
                      image: UIImage?,
                      tintColor: UIColor,
                      action: @escaping () -> Void) -> TKUIListItemCell.Configuration {
    let accessoryConfiguration: TKUIListItemAccessoryView.Configuration
    if let image {
      accessoryConfiguration = .image(
        TKUIListItemImageAccessoryView.Configuration(
          image: image,
          tintColor: tintColor,
          padding: .zero
        )
      )
    } else {
      accessoryConfiguration = .none
    }
    
    return TKUIListItemCell.Configuration(
      id: id,
      listItemConfiguration: TKUIListItemView.Configuration(
        contentConfiguration: TKUIListItemContentView.Configuration(
          leftItemConfiguration: TKUIListItemContentLeftItem.Configuration(
            title: title.withTextStyle(
              .label1,
              color: .Text.primary,
              alignment: .left,
              lineBreakMode: .byTruncatingTail
            ),
            tagViewModel: nil,
            subtitle: nil,
            description: subtitle?.withTextStyle(.body2, color: .Text.secondary)
          ),
          rightItemConfiguration: nil
        ),
        accessoryConfiguration: accessoryConfiguration
      ),
      selectionClosure: {
        action()
      }
    )
  }
}

private extension String {
  static let deleteItemIdentifier = "DeleteItemIdentifier"
  static let nameItemIdentifier = "NameItemIdentifier"
  static let hexItemIdentifier = "HexItemIdentifier"
  static let recoveryPhraseItemIdentifier = "RecoveryPhraseItemIdentifier"
  static let linkToWebItemIdentifier = "LinkToWebItemIdentifier"
  static let linkToDeviceItemIdentifier = "LinkToDeviceItemIdentifier"
  static let qrCodeDescriptionItemIdentifier = "QRCodeDescriptionItemIdentifier"
}

//  func createSections() -> [SettingsListSection] {
//    [
//      SettingsListSection(
//        items: [
//          SettingsListItem(
//            id: UUID().uuidString,
//            model: AccessoryListItemView<TwoLinesListItemView>.Model(
//              contentViewModel: TwoLinesListItemView.Model(
//                title: "Change Password"
//              ),
//              accessoryModel: .icon(.TKUIKit.Icons.List.Accessory.password, .Accent.blue)
//            ),
//            action: { [weak self] in
//              self?.didTapChangePassword?()
//            }
//          )
//        ]
//      ),
//      SettingsListSection(
//        items: [
//          SettingsListItem(
//            id: UUID().uuidString,
//            model: AccessoryListItemView<TwoLinesListItemView>.Model(
//              contentViewModel: TwoLinesListItemView.Model(
//                title: "Support"
//              ),
//              accessoryModel: .icon(.TKUIKit.Icons.List.Accessory.support, .Icon.secondary)
//            )
//          ),
//          SettingsListItem(
//            id: UUID().uuidString,
//            model: AccessoryListItemView<TwoLinesListItemView>.Model(
//              contentViewModel: TwoLinesListItemView.Model(
//                title: "Legal"
//              ),
//              accessoryModel: .icon(.TKUIKit.Icons.List.Accessory.legal, .Icon.secondary)
//            )
//          )
//        ]
//      )
//    ]
//  }
//}

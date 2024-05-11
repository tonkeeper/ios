import UIKit
import TKUIKit
import SignerLocalize

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
    titleUpdate?(SignerLocalize.Settings.title)
    
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
                       title: SignerLocalize.Settings.Items.change_password,
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
                       title: SignerLocalize.Settings.Items.support,
                       image: .TKUIKit.Icons.Size28.messageBubble,
                       tintColor: .Icon.secondary,
                       action: {
                         
                       }),
        createListItem(id: "LegalIdentifier",
                       title: SignerLocalize.Settings.Items.legal,
                       image: .TKUIKit.Icons.Size28.messageBubble,
                       tintColor: .Icon.secondary,
                       action: {
                         
                       })
      ]
    )
  }
  
  func createFooterSection() -> SettingsSection {
    SettingsSection(items: [
      SettingsListFooterCell.Model(top: SignerLocalize.App.name, 
                                   bottom: "\(SignerLocalize.Settings.Footer.version(1.0))")
    ])
  }
  
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

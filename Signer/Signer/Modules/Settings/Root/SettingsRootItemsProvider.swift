import UIKit
import TKUIKit
import SignerLocalize

final class SettingsRootItemsProvider: SettingsLiteItemsProvider {
  
  var title: String {
    SignerLocalize.Settings.title
  }
  var didUpdate: (() -> Void)?
  var showPopupMenu: (([TKPopupMenuItem], Int?, IndexPath) -> Void)?
  
  var didTapChangePassword: (() -> Void)?
  var didTapLegal: (() -> Void)?
  
  private let urlOpener: URLOpener
  
  init(urlOpener: URLOpener) {
    self.urlOpener = urlOpener
    TKThemeManager.shared.addEventObserver(self) { observer, _ in
      observer.didUpdate?()
    }
  }
  
  func getSections() -> [SettingsSection] {
    createSections()
  }
  
  func createSections() -> [SettingsSection] {
    return [
      createFirstSection(),
      createSecondSection(),
      createThirdSection(),
      createFooterSection()
    ]
  }
  
  func createFirstSection() -> SettingsSection {
    SettingsSection(
      items: [
        createListItem(id: "ChangePasswordIdentifier",
                       title: SignerLocalize.Settings.Items.change_password,
                       accessory: .image(.TKUIKit.Icons.Size28.lock),
                       tintColor: .Accent.blue,
                       action: { [weak self] in
                         self?.didTapChangePassword?()
                       })
      ]
    )
  }
  
  func createSecondSection() -> SettingsSection {
    return SettingsSection(
      items: [
        createListItem(id: "ThemeIdentifier",
                       title: SignerLocalize.Settings.Items.theme,
                       accessory: .text(TKThemeManager.shared.theme.localizedTitle),
                       tintColor: .Accent.blue,
                       action: { [weak self] in
                         let items = TKTheme.allCases.map { theme in
                           TKPopupMenuItem(title: theme.localizedTitle,
                                           value: nil,
                                           description: nil,
                                           icon: nil) {
                             TKThemeManager.shared.theme = theme
                           }
                         }
                         let selectedIndex = TKTheme.allCases.firstIndex(of: TKThemeManager.shared.theme)
                         self?.showPopupMenu?(items, selectedIndex, IndexPath(item: 0, section: 1))
                       })
      ]
    )
  }
  
  func createThirdSection() -> SettingsSection {
    SettingsSection(
      items: [
        createListItem(id: "SupportIdentifier",
                       title: SignerLocalize.Settings.Items.support,
                       accessory: .image(.TKUIKit.Icons.Size28.messageBubble),
                       tintColor: .Accent.blue,
                       action: { [urlOpener] in
                         guard let url = InfoProvider.supportURL() else { return }
                         urlOpener.open(url: url)
                       }),
        createListItem(id: "LegalIdentifier",
                       title: SignerLocalize.Settings.Items.legal,
                       accessory: .image(.TKUIKit.Icons.Size28.doc),
                       tintColor: .Icon.secondary,
                       action: { [weak self] in
                         self?.didTapLegal?()
                       })
      ]
    )
  }
  
  func createFooterSection() -> SettingsSection {
    var string = ""
    if let version = InfoProvider.appVersion() {
      string += version
    }
    if let build = InfoProvider.buildVersion() {
      string += "(\(build))"
    }
    
    return SettingsSection(items: [
      SettingsListFooterCell.Model(top: SignerLocalize.App.name,
                                   bottom: "\(SignerLocalize.Settings.Footer.version(string))")
    ])
  }
  
  private enum Accessory {
    case none
    case text(String)
    case image(UIImage)
  }
  private func createListItem(id: String,
                      title: String,
                      subtitle: String? = nil,
                      accessory: Accessory,
                      tintColor: UIColor,
                      action: @escaping () -> Void) -> TKUIListItemCell.Configuration {
    let accessoryConfiguration: TKUIListItemAccessoryView.Configuration
    switch accessory {
    case .none:
      accessoryConfiguration = .none
    case .text(let string):
      accessoryConfiguration = .text(
        TKUIListItemTextAccessoryView.Configuration(
          text: string.withTextStyle(.label1, color: tintColor)
        )
      )
    case .image(let image):
      accessoryConfiguration = .image(
        TKUIListItemImageAccessoryView.Configuration(
          image: image,
          tintColor: tintColor,
          padding: .zero
        )
      )
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

private extension TKTheme {
  var localizedTitle: String {
    switch self {
    case .deepBlue:
      return SignerLocalize.Settings.Themes.deepblue
    case .dark:
      return SignerLocalize.Settings.Themes.dark
    case .light:
      return SignerLocalize.Settings.Themes.light
    case .system:
      return SignerLocalize.Settings.Themes.system
    }
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

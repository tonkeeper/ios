import UIKit
import TKUIKit
import SignerLocalize

final class SettingsLegalItemsProvider: SettingsLiteItemsProvider {
  var title: String {
    SignerLocalize.Settings.Legal.title
  }
  var didUpdate: (() -> Void)?
  var showPopupMenu: (([TKPopupMenuItem], Int?, IndexPath) -> Void)?
  
  var didSelectFontLicense: (() -> Void)?
  
  private let urlOpener: URLOpener
  
  init(urlOpener: URLOpener) {
    self.urlOpener = urlOpener
  }
  
  func getSections() -> [SettingsSection] {
    createSections()
  }
  
  func createSections() -> [SettingsSection] {
    return [
      createFirstSection(),
      createSecondSection()
    ]
  }
  
  func createFirstSection() -> SettingsSection {
    SettingsSection(
      items: [
        createListItem(id: "TermsOfServiceIdentifier",
                       title: SignerLocalize.Settings.Legal.Items.terms_of_service,
                       action: { [weak self] in
                         guard let url = InfoProvider.termsOfServiceURL() else { return }
                         self?.urlOpener.open(url: url)
                       }),
        createListItem(id: "PrivacyPolicyIdentifier",
                       title: SignerLocalize.Settings.Legal.Items.privacy_policy,
                       action: { [weak self] in
                         guard let url = InfoProvider.privacyPolicyURL() else { return }
                         self?.urlOpener.open(url: url)
                       })
      ]
    )
  }
  
  func createSecondSection() -> SettingsSection {
    SettingsSection(
      title: SignerLocalize.Settings.Legal.Sections.licenses,
      items: [
        createListItem(id: "MontserratFontIdentifier",
                       title: SignerLocalize.Settings.Legal.Items.montserrat_font,
                       action: { [weak self] in
                         self?.didSelectFontLicense?()
                       })
      ]
    )
  }
  
  func createListItem(id: String,
                      title: String,
                      action: @escaping () -> Void) -> TKUIListItemCell.Configuration {
    let accessoryConfiguration: TKUIListItemAccessoryView.Configuration = .image(
      TKUIListItemImageAccessoryView.Configuration(
        image: .TKUIKit.Icons.Size16.chevronRight,
        tintColor: .Icon.tertiary,
        padding: .zero
      )
    )
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
            description: nil
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

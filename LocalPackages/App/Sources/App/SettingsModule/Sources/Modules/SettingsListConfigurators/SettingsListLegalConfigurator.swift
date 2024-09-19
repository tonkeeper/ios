import UIKit
import TKUIKit
import KeeperCore
import TKLocalize
import TKCore

final class SettingsListLegalConfigurator: SettingsListConfigurator {
  
  var didTapFontLicense: (() -> Void)?
  var openUrl: ((URL) -> Void)?
  
  // MARK: - SettingsListV2Configurator
  
  var didUpdateState: ((SettingsListState) -> Void)?
  var didShowPopupMenu: (([TKPopupMenuItem], Int?) -> Void)?
  
  var title: String { TKLocales.Settings.Legal.title }
  var isSelectable: Bool { false }
  
  func getInitialState() -> SettingsListState {
    createState()
  }
  
  private func createState() -> SettingsListState {
    let sections = [
      createDocumentsSection(),
      createFontLicenseSection()
    ]
    return SettingsListState(
      sections: sections
    )
  }
  
  private func createDocumentsSection() -> SettingsListSection {
    .listItems(
      SettingsListItemsSection(
        items: [
          createTermsOfServiceItem(),
          createPrivacyPolicyItem()
        ],
        topPadding: 0,
        bottomPadding: 16
      )
    )
  }
  
  private func createFontLicenseSection() -> SettingsListSection {
    .listItems(
      SettingsListItemsSection(
        items: [
          createFontLicenseItem()
        ],
        topPadding: 0,
        bottomPadding: 16,
        headerConfiguration: SettingsListSectionHeaderView.Configuration(
          title: TKLocales.Settings.Legal.Sections.licenses
        )
      )
    )
  }
  
  private func createTermsOfServiceItem() -> SettingsListItem {
    let cellConfiguration = TKListItemCell.Configuration(
      listItemContentViewConfiguration: TKListItemContentView.Configuration(
        textContentViewConfiguration: TKListItemTextContentView.Configuration(
          titleViewConfiguration: TKListItemTitleView.Configuration(title: TKLocales.Settings.Legal.Items.termsOfService)
        )))
    return SettingsListItem(
      id: .termsOfServiceIdentifier,
      cellConfiguration: cellConfiguration,
      accessory: .chevron,
      onSelection: { [weak self] _ in
        guard let url = InfoProvider.termsOfServiceURL() else { return }
        self?.openUrl?(url)
      }
    )
  }
  
  private func createPrivacyPolicyItem() -> SettingsListItem {
    let cellConfiguration = TKListItemCell.Configuration(
      listItemContentViewConfiguration: TKListItemContentView.Configuration(
        textContentViewConfiguration: TKListItemTextContentView.Configuration(
          titleViewConfiguration: TKListItemTitleView.Configuration(title: TKLocales.Settings.Legal.Items.privacyPolicy)
        )))
    return SettingsListItem(
      id: .privacyPolicyIdentifier,
      cellConfiguration: cellConfiguration,
      accessory: .chevron,
      onSelection: { [weak self] _ in
        guard let url = InfoProvider.privacyPolicyURL() else { return }
        self?.openUrl?(url)
      }
    )
  }
  
  private func createFontLicenseItem() -> SettingsListItem {
    let cellConfiguration = TKListItemCell.Configuration(
      listItemContentViewConfiguration: TKListItemContentView.Configuration(
        textContentViewConfiguration: TKListItemTextContentView.Configuration(
          titleViewConfiguration: TKListItemTitleView.Configuration(title: TKLocales.Settings.Legal.Items.montserratFont)
        )))
    return SettingsListItem(
      id: .montserratFontIdentifier,
      cellConfiguration: cellConfiguration,
      accessory: .chevron,
      onSelection: { [weak self] _ in
        self?.didTapFontLicense?()
      }
    )
  }
}

private extension String {
  static let termsOfServiceIdentifier = "termsOfServiceIdentifier"
  static let privacyPolicyIdentifier = "privacyPolicyIdentifier"
  static let montserratFontIdentifier = "montserratFontIdentifier"
}

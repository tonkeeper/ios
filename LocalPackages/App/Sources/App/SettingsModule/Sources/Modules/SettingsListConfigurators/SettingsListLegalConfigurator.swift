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
    SettingsListState(sections: [])
  }
//  func getState() -> SettingsListState {
//    createState()
//  }
}
//
//private extension SettingsListLegalConfigurator {
//  func createState() -> SettingsListState {
//    return SettingsListState(
//      sections: [
//        createFirstSection(),
//        createSecondSection()
//      ],
//      selectedItem: nil
//    )
//  }
//  
//  func createFirstSection() -> SettingsListSection {
//    var items = [AnyHashable]()
//    
//    let termsOfServiceItem = TKUIListItemCell.Configuration.createSettingsItem(
//      id: .termsOfServiceIdentifier,
//      title: .string(
//        TKLocales.Settings.Legal.Items.terms_of_service
//      ),
//      accessory: .icon(.TKUIKit.Icons.Size16.chevronRight, .Icon.tertiary),
//      selectionClosure: { [weak self] in
//        guard let url = InfoProvider.termsOfServiceURL() else { return }
//        self?.openUrl?(url)
//      }
//    )
//    items.append(termsOfServiceItem)
//    
//    let privacyPolicyItem = TKUIListItemCell.Configuration.createSettingsItem(
//      id: .privacyPolicyIdentifier,
//      title: .string(
//        TKLocales.Settings.Legal.Items.privacy_policy
//      ),
//      accessory: .icon(.TKUIKit.Icons.Size16.chevronRight, .Icon.tertiary),
//      selectionClosure: { [weak self] in
//        guard let url = InfoProvider.privacyPolicyURL() else { return }
//        self?.openUrl?(url)
//      }
//    )
//    items.append(privacyPolicyItem)
//    
//    return SettingsListSection.items(
//      topPadding: 0,
//      items: items,
//      header: nil,
//      bottomDescription: nil
//    )
//  }
//  
//  func createSecondSection() -> SettingsListSection {
//    return SettingsListSection.items(
//      topPadding: 0,
//      items: [
//        TKUIListItemCell.Configuration.createSettingsItem(
//          id: .montserratFontIdentifier,
//          title: .string(TKLocales.Settings.Legal.Items.montserrat_font),
//          accessory: .icon(.TKUIKit.Icons.Size16.chevronRight, .Icon.tertiary),
//          selectionClosure: { [weak self] in
//            self?.didTapFontLicense?()
//          }
//        )
//      ],
//      header: TKLocales.Settings.Legal.Sections.licenses,
//      bottomDescription: nil
//    )
//  }
//}
//
//private extension String {
//  static let termsOfServiceIdentifier = "termsOfServiceIdentifier"
//  static let privacyPolicyIdentifier = "privacyPolicyIdentifier"
//  static let montserratFontIdentifier = "montserratFontIdentifier"
//}

import Foundation
import TKUIKit

protocol SettingsModuleOutput: AnyObject {
  var didTapChangePassword: (() -> Void)? { get set }
}

protocol SettingsViewModel: AnyObject {
  var titleUpdate: ((String) -> Void)? { get set }
  var itemsListUpdate: (([SettingsListSection]) -> Void)? { get set }
  var footerUpdate: ((SettingsListFooterView.Model) -> Void)? { get set }
  
  func viewDidLoad()
}

final class SettingsViewModelImplementation: SettingsViewModel, SettingsModuleOutput {
  
  // MARK: - SettingsModuleOutput
  
  var didTapChangePassword: (() -> Void)?
  
  // MARK: - SettingsViewModel
  
  var titleUpdate: ((String) -> Void)?
  var itemsListUpdate: (([SettingsListSection]) -> Void)?
  var footerUpdate: ((SettingsListFooterView.Model) -> Void)?
  
  func viewDidLoad() {
    titleUpdate?("Settings")
    
    itemsListUpdate?(createSections())
    
    footerUpdate?(SettingsListFooterView.Model(
      top: "Signer",
      bottom: "Version 1.0"
    ))
  }
}

private extension SettingsViewModelImplementation {
  func createSections() -> [SettingsListSection] {
    [
      SettingsListSection(
        items: [
          SettingsListItem(
            id: UUID().uuidString,
            model: AccessoryListItemView<TwoLinesListItemView>.Model(
              contentViewModel: TwoLinesListItemView.Model(
                title: "Change Password"
              ),
              accessoryModel: .icon(.TKUIKit.Icons.List.Accessory.password, .Accent.blue)
            ),
            action: { [weak self] in
              self?.didTapChangePassword?()
            }
          )
        ]
      ),
      SettingsListSection(
        items: [
          SettingsListItem(
            id: UUID().uuidString,
            model: AccessoryListItemView<TwoLinesListItemView>.Model(
              contentViewModel: TwoLinesListItemView.Model(
                title: "Support"
              ),
              accessoryModel: .icon(.TKUIKit.Icons.List.Accessory.support, .Icon.secondary)
            )
          ),
          SettingsListItem(
            id: UUID().uuidString,
            model: AccessoryListItemView<TwoLinesListItemView>.Model(
              contentViewModel: TwoLinesListItemView.Model(
                title: "Legal"
              ),
              accessoryModel: .icon(.TKUIKit.Icons.List.Accessory.legal, .Icon.secondary)
            )
          )
        ]
      )
    ]
  }
}

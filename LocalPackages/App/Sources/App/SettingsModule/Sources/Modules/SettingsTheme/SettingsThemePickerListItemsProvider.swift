import UIKit
import TKUIKit
import TKCore

final class SettingsThemePickerListItemsProvider: SettingsListItemsProvider {
  private let appSettings: AppSettings
  
  init(appSettings: AppSettings) {
    self.appSettings = appSettings
  }
  
  var didUpdateSections: (() -> Void)?
  var didSelectItem: ((SettingsListSection, Int) -> Void)?
  
  var title: String { "Theme" }
  
  func getSections() -> [SettingsListSection] {
    [createSection()]
  }
  
  func selectItem(section: SettingsListSection, index: Int) {
    switch section.items[index] {
    case let walletModel as WalletsListWalletCell.Model:
      walletModel.selectionHandler?()
    default:
      break
    }
  }
  
  func cell(collectionView: UICollectionView, indexPath: IndexPath, itemIdentifier: AnyHashable) -> UICollectionViewCell? {
    nil
  }
  
  func initialSelectedIndexPath() async -> IndexPath? {
    guard let index = ThemeMode.allCases.firstIndex(of: appSettings.themeMode()) else {
      return nil
    }
    return IndexPath(row: index, section: 0)
  }
}

private extension SettingsThemePickerListItemsProvider {
  func createSection() -> SettingsListSection {
    let items = ThemeMode.allCases.map { themeMode in
      let title = themeMode.title.withTextStyle(
        .label1,
        color: .Text.primary,
        alignment: .left,
        lineBreakMode: .byTruncatingTail
      )
      
      return SettingsCell.Model(
        identifier: themeMode.rawValue,
        isSelectable: true,
        selectionHandler: { [weak self] in
          guard let self else { return }
          self.appSettings.setThemeMode(themeMode)
          NotificationCenter.default.post(
            name: NSNotification.Name.didChangeThemeMode, 
            object: nil,
            userInfo: [ThemeMode.notificationUserInfoKey: themeMode]
          )
        },
        cellContentModel: SettingsCellContentView.Model(
          title: title
        )
      )
    }
    return SettingsListSection(padding: .sectionPadding,
                               items: items)
  }
}

private extension NSDirectionalEdgeInsets {
  static let sectionPadding = NSDirectionalEdgeInsets(
    top: 16,
    leading: 16,
    bottom: 16,
    trailing: 16
  )
}

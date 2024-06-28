import UIKit
import TKUIKit
import TKCore
import TKLocalize

final class SettingsThemePickerListItemsProvider: SettingsListItemsProvider {
  private let appSettings: AppSettings
  
  init(appSettings: AppSettings) {
    self.appSettings = appSettings
  }
  
  var didUpdateSections: (() -> Void)?
  var didSelectItem: ((SettingsListSection, Int) -> Void)?
  
  var title = TKLocales.Theme.title
  
  func getSections() -> [SettingsListSection] {
    [createSection()]
  }
  
  func selectItem(section: SettingsListSection, index: Int) {}
  
  func cell(collectionView: UICollectionView, indexPath: IndexPath, itemIdentifier: AnyHashable) -> UICollectionViewCell? {
    nil
  }
  
  func initialSelectedIndexPath() async -> IndexPath? {
    guard let index = TKTheme.allCases.firstIndex(of: TKThemeManager.shared.theme) else {
      return nil
    }
    return IndexPath(row: index, section: 0)
  }
}

private extension SettingsThemePickerListItemsProvider {
  func createSection() -> SettingsListSection {
    let items = TKTheme.allCases.map { theme in
      let title = theme.title.withTextStyle(
        .label1,
        color: .Text.primary,
        alignment: .left,
        lineBreakMode: .byTruncatingTail
      )
      
      return SettingsCell.Model(
        identifier: theme.rawValue,
        isSelectable: true,
        selectionHandler: {
          TKThemeManager.shared.theme = theme
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

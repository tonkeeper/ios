import UIKit
import TKUIKit
import KeeperCore
import TKLocalize

final class SettingsCurrencyPickerListItemsProvider: SettingsListItemsProvider {
  private let settingsController: SettingsController
  
  init(settingsController: SettingsController) {
    self.settingsController = settingsController
  }
  
  var didUpdateSections: (() -> Void)?
  var didSelectItem: ((SettingsListSection, Int) -> Void)?
  
  var title = TKLocales.Currency.title
  
  func getSections() -> [SettingsListSection] {
    [createSection()]
  }
  
  func selectItem(section: SettingsListSection, index: Int) {}
  
  func cell(collectionView: UICollectionView, indexPath: IndexPath, itemIdentifier: AnyHashable) -> UICollectionViewCell? {
    nil
  }
  
  func initialSelectedIndexPath() async -> IndexPath? {
    guard let index = settingsController.getAvailableCurrencies().firstIndex(of: await settingsController.activeCurrency()) else {
      return nil
    }
    return IndexPath(row: index, section: 0)
  }
}

private extension SettingsCurrencyPickerListItemsProvider {
  func createSection() -> SettingsListSection {
    let currencies = settingsController.getAvailableCurrencies()
    let items = currencies.map { currency in
      let title = NSMutableAttributedString()
      
      let code = "\(currency.code) ".withTextStyle(
        .label1,
        color: .Text.primary,
        alignment: .left,
        lineBreakMode: .byTruncatingTail
      )
      
      let name = currency.title.withTextStyle(
        .body1,
        color: .Text.secondary,
        alignment: .left,
        lineBreakMode: .byTruncatingTail
      )
      
      title.append(code)
      title.append(name)
      
      return SettingsCell.Model(
        identifier: currency.title,
        isSelectable: true,
        selectionHandler: { [weak self] in
          guard let self else { return }
          Task {
            await self.settingsController.setCurrency(currency)
          }
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

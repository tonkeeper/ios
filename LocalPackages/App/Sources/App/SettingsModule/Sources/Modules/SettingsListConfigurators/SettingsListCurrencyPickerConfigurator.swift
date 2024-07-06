import UIKit
import TKUIKit
import KeeperCore
import TKLocalize
import TKCore

final class SettingsListCurrencyPickerConfigurator: SettingsListV2Configurator {
  
  // MARK: - SettingsListV2Configurator
  
  var didUpdateState: ((SettingsListV2State) -> Void)?
  
  var title: String { TKLocales.Currency.title }
  var isSelectable: Bool { true }
  
  func getState() -> SettingsListV2State {
    let currency = currencyStore.getState()
    return createState(selectedCurrency: currency)
  }
  
  // MARK: - State
  
  private let actor = SerialActor<Void>()
  
  // MARK: - Dependencies
  
  private let currencyStore: CurrencyStoreV2
  
  // MARK: - Init
  
  init(currencyStore: CurrencyStoreV2) {
    self.currencyStore = currencyStore
  }
}

private extension SettingsListCurrencyPickerConfigurator {
  func createState(selectedCurrency: Currency) -> SettingsListV2State {
    let currencies = Currency.allCases
    var items = [AnyHashable]()
    var selectedItem: AnyHashable?
    currencies.forEach { currency in
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
      
      let contentConfiguration = TKUIListItemContentView.Configuration(
        leftItemConfiguration: TKUIListItemContentLeftItem.Configuration(
          title: title,
          tagViewModel: nil,
          subtitle: nil,
          description: nil
        ),
        rightItemConfiguration: nil
      )
      
      let listItemConfiguration = TKUIListItemView.Configuration(
        iconConfiguration: TKUIListItemIconView.Configuration(
          iconConfiguration: .none,
          alignment: .center
        ),
        contentConfiguration: contentConfiguration,
        accessoryConfiguration: .none
      )
      
      let configuration = TKUIListItemCell.Configuration(
        id: currency.code,
        listItemConfiguration: listItemConfiguration,
        isHighlightable: true,
        selectionClosure: { [weak self] in
          guard let self else { return }
          Task {
            await self.currencyStore.setCurrency(currency)
          }
        }
      )
      items.append(configuration)
      
      if currency == selectedCurrency {
        selectedItem = configuration
      }
    }
    
    let section = SettingsListV2Section.items(topPadding: 14, items: items)
    
    return SettingsListV2State(sections: [section], selectedItem: selectedItem)
  }
}
//import UIKit
//import TKUIKit
//import KeeperCore
//import TKLocalize
//
//final class SettingsCurrencyPickerListItemsProvider: SettingsListItemsProvider {
//  private let settingsController: SettingsController
//
//  init(settingsController: SettingsController) {
//    self.settingsController = settingsController
//  }
//
//  var didUpdateSections: (() -> Void)?
//  var didSelectItem: ((SettingsListSection, Int) -> Void)?
//
//  var title = TKLocales.Currency.title
//
//  func getSections() -> [SettingsListSection] {
//    [createSection()]
//  }
//
//  func selectItem(section: SettingsListSection, index: Int) {}
//
//  func cell(collectionView: UICollectionView, indexPath: IndexPath, itemIdentifier: AnyHashable) -> UICollectionViewCell? {
//    nil
//  }
//
//  func initialSelectedIndexPath() async -> IndexPath? {
//    guard let index = settingsController.getAvailableCurrencies().firstIndex(of: await settingsController.activeCurrency()) else {
//      return nil
//    }
//    return IndexPath(row: index, section: 0)
//  }
//}
//
//private extension SettingsCurrencyPickerListItemsProvider {
//  func createSection() -> SettingsListSection {
//    let currencies = settingsController.getAvailableCurrencies()
//    let items = currencies.map { currency in
//      let title = NSMutableAttributedString()
//
//      let code = "\(currency.code) ".withTextStyle(
//        .label1,
//        color: .Text.primary,
//        alignment: .left,
//        lineBreakMode: .byTruncatingTail
//      )
//
//      let name = currency.title.withTextStyle(
//        .body1,
//        color: .Text.secondary,
//        alignment: .left,
//        lineBreakMode: .byTruncatingTail
//      )
//
//      title.append(code)
//      title.append(name)
//
//      return SettingsCell.Model(
//        identifier: currency.title,
//        isSelectable: true,
//        selectionHandler: { [weak self] in
//          guard let self else { return }
//          Task {
//            await self.settingsController.setCurrency(currency)
//          }
//        },
//        cellContentModel: SettingsCellContentView.Model(
//          title: title
//        )
//      )
//    }
//    return SettingsListSection(padding: .sectionPadding,
//                               items: items)
//  }
//}
//
//private extension NSDirectionalEdgeInsets {
//  static let sectionPadding = NSDirectionalEdgeInsets(
//    top: 16,
//    leading: 16,
//    bottom: 16,
//    trailing: 16
//  )
//}

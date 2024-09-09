import UIKit
import TKUIKit
import KeeperCore
import TKLocalize
import TKCore

final class SettingsListCurrencyPickerConfigurator: SettingsListConfigurator {
  
  var didSelect: (() -> Void)?
  
  // MARK: - SettingsListV2Configurator
  
  var didUpdateState: ((SettingsListState) -> Void)?
  var title: String { TKLocales.Currency.title }
  var selectedItems = Set<SettingsListItem>()
  
  func getInitialState() -> SettingsListState {
    createState()
  }

  
  // MARK: - Dependencies
  
  private let currencyStore: CurrencyStore
  
  // MARK: - Init
  
  init(currencyStore: CurrencyStore) {
    self.currencyStore = currencyStore
  }
  
  private func createState() -> SettingsListState {
    let selectedCurrency = currencyStore.getState()
    let currencies = Currency.allCases
    var items = [SettingsListItem]()
    currencies.forEach { currency in
      let cellConfiguration = TKListItemCell.Configuration(
        listItemContentViewConfiguration: TKListItemContentViewV2.Configuration(
          textContentViewConfiguration: TKListItemTextContentViewV2.Configuration(
            titleViewConfiguration: TKListItemTitleView.Configuration(title: currency.code,
                                                                      caption: currency.title)
          )))
      let item = SettingsListItem(
        id: currency.code,
        cellConfiguration: cellConfiguration,
        accessory: .none,
        selectAccessory: .icon(TKListItemIconAccessoryView.Configuration(icon: .TKUIKit.Icons.Size28.donemarkOutline, tintColor: .Accent.blue)),
        onSelection: { [weak self] view in
          guard let self else { return }
          Task {
            await self.currencyStore.setCurrency(currency)
            await MainActor.run {
              self.didSelect?()
            }
          }
        }
      )
      items.append(item)
      
      if currency == selectedCurrency {
        selectedItems.removeAll()
        selectedItems.insert(item)
      }
    }
    
    let section = SettingsListSection.listItems(
      SettingsListItemsSection(
        items: items,
        topPadding: 0,
        bottomPadding: 16
      )
    )
    
    return SettingsListState(sections: [section])
  }
}

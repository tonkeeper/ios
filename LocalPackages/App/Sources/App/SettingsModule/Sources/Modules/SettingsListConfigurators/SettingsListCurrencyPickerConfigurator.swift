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
    let selectedCurrency = currencyStore.getCurrency()
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
//
//private extension SettingsListCurrencyPickerConfigurator {
//  func createState(selectedCurrency: Currency) -> SettingsListState {
//    let currencies = Currency.allCases
//    var items = [AnyHashable]()
//    var selectedItem: AnyHashable?
//    currencies.forEach { currency in
//      let title = NSMutableAttributedString()
//      let code = "\(currency.code) ".withTextStyle(
//        .label1,
//        color: .Text.primary,
//        alignment: .left,
//        lineBreakMode: .byTruncatingTail
//      )
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
//      let contentConfiguration = TKUIListItemContentView.Configuration(
//        leftItemConfiguration: TKUIListItemContentLeftItem.Configuration(
//          title: title,
//          tagViewModel: nil,
//          subtitle: nil,
//          description: nil
//        ),
//        rightItemConfiguration: nil
//      )
//      
//      let listItemConfiguration = TKUIListItemView.Configuration(
//        iconConfiguration: TKUIListItemIconView.Configuration(
//          iconConfiguration: .none,
//          alignment: .center
//        ),
//        contentConfiguration: contentConfiguration,
//        accessoryConfiguration: .none
//      )
//      
//      let configuration = TKUIListItemCell.Configuration(
//        id: currency.code,
//        listItemConfiguration: listItemConfiguration,
//        isHighlightable: true,
//        selectionClosure: { [weak self] in
//          guard let self else { return }
//          Task {
//            await self.currencyStore.setCurrency(currency)
//          }
//        }
//      )
//      items.append(configuration)
//      
//      if currency == selectedCurrency {
//        selectedItem = configuration
//      }
//    }
//    
//    let section = SettingsListSection.items(topPadding: 14, items: items)
//    
//    return SettingsListState(sections: [section], selectedItem: selectedItem)
//  }
//}

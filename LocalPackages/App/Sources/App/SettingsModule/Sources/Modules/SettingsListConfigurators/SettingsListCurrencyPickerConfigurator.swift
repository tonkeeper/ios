import UIKit
import TKUIKit
import KeeperCore
import TKLocalize
import TKCore

final class SettingsListCurrencyPickerConfigurator: SettingsListConfigurator {
  func getInitialState() -> SettingsListState {
    SettingsListState(sections: [])
  }
  
  
  // MARK: - SettingsListV2Configurator
  
  var didUpdateState: ((SettingsListState) -> Void)?
  var didShowPopupMenu: (([TKPopupMenuItem], Int?) -> Void)?
  
  var title: String { TKLocales.Currency.title }
  var isSelectable: Bool { true }
  
//  func getState() -> SettingsListState {
//    let currency = currencyStore.getState()
//    return createState(selectedCurrency: currency)
//  }
  
  // MARK: - State
  
  private let actor = SerialActor<Void>()
  
  // MARK: - Dependencies
  
  private let currencyStore: CurrencyStore
  
  // MARK: - Init
  
  init(currencyStore: CurrencyStore) {
    self.currencyStore = currencyStore
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

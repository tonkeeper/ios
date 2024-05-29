//import UIKit
//import TKUIKit
//import KeeperCore
//import TKLocalize
//
//final class BuySellCurrencyListItemsProvider: SettingsListItemsProvider {
//  private let items: [FiatMethodLayout]
//  private let selectedItem: String
//  
//  init(items: [FiatMethodLayout], selectedItem: String) {
//    self.items = items
//    self.selectedItem = selectedItem
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
//  func selectItem(section: SettingsListSection, index: Int) {
//    switch section.items[index] {
//    case let walletModel as WalletsListWalletCell.Model:
//      walletModel.selectionHandler?()
//    default:
//      break
//    }
//  }
//  
//  func cell(collectionView: UICollectionView, indexPath: IndexPath, itemIdentifier: AnyHashable) -> UICollectionViewCell? {
//    nil
//  }
//  
//  func initialSelectedIndexPath() async -> IndexPath? {
//    guard let index = items.firstIndex(where: { it in
//      it.currency == selectedItem
//    }) else {
//      return nil
//    }
//    return IndexPath(row: index, section: 0)
//  }
//}
//
//private extension BuySellCurrencyListItemsProvider {
//  func createSection() -> SettingsListSection {
//    let currencies = settingsController.getAvailableCurrencies()
//    let items = self.items.map { currency in
//      let title = NSMutableAttributedString()
//      
//      let code = "\(currency.countryCode ?? "") ".withTextStyle(
//        .label1,
//        color: .Text.primary,
//        alignment: .left,
//        lineBreakMode: .byTruncatingTail
//      )
//      
//      let name = (currency.currency ?? "").withTextStyle(
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
//        identifier: currency.currency ?? "",
//        isSelectable: true,
//        selectionHandler: { [weak self] in
//          guard let self else { return }
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

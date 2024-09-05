import Foundation
import TKUIKit
import KeeperCore

enum WalletBalanceSection: Hashable {
  case balance(WalletBalanceListSection)
  case setup(WalletBalanceSetupSection)
  case notifications(WalletBalanceNotificationSection)
}

struct WalletBalanceListSection: Hashable {
  let items: [WalletBalanceListItem]
  let footerConfiguration: TKListCollectionViewButtonFooterView.Configuration?
  
  init(items: [WalletBalanceListItem],
       footerConfiguration: TKListCollectionViewButtonFooterView.Configuration? = nil) {
    self.items = items
    self.footerConfiguration = footerConfiguration
  }
}

struct WalletBalanceSetupSection: Hashable {
  let items: [WalletBalanceListItem]
  let headerConfiguration: TKListCollectionViewButtonHeaderView.Configuration
  
  init(items: [WalletBalanceListItem], 
       headerConfiguration: TKListCollectionViewButtonHeaderView.Configuration) {
    self.items = items
    self.headerConfiguration = headerConfiguration
  }
}

struct WalletBalanceNotificationSection: Hashable {
  let items: [WalletBalanceNotificationItem]
}

struct WalletBalanceListItem: Hashable {
  let identifier: String
  let accessory: TKListItemAccessory?
  let onSelection: (() -> Void)?
  
  static func == (lhs: WalletBalanceListItem, rhs: WalletBalanceListItem) -> Bool {
    lhs.identifier == rhs.identifier
  }
  
  func hash(into hasher: inout Hasher) {
    hasher.combine(identifier)
  }
  
  init(identifier: String, 
       accessory: TKListItemAccessory? = nil,
       onSelection: (() -> Void)?) {
    self.identifier = identifier
    self.accessory = accessory
    self.onSelection = onSelection
  }
}

class WalletBalanceNotificationItem: Hashable {
  let id: String
  let cellConfiguration: NotificationBannerCell.Configuration
  
  static func == (lhs: WalletBalanceNotificationItem, rhs: WalletBalanceNotificationItem) -> Bool {
    lhs.id == rhs.id
  }
  
  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
  
  init(id: String,
       cellConfiguration: NotificationBannerCell.Configuration) {
    self.id = id
    self.cellConfiguration = cellConfiguration
  }
}

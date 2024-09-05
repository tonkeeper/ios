import UIKit

public enum TKListItemAccessory {
  case chevron
  case icon(TKListItemIconAccessoryView.Configuration)
  case text(TKListItemTextAccessoryView.Configuration)
  case `switch`(TKListItemSwitchAccessoryView.Configuration)
  
  public var view: UIView? {
    switch self {
    case .chevron:
      let accessoryView = TKListItemIconAccessoryView()
      accessoryView.configuration = .chevron
      return accessoryView
    case .icon(let configuration):
      let accessoryView = TKListItemIconAccessoryView()
      accessoryView.configuration = configuration
      return accessoryView
    case .text(let configuration):
      let accessoryView = TKListItemTextAccessoryView()
      accessoryView.configuration = configuration
      return accessoryView
    case .switch(let configuration):
      let accessoryView = TKListItemSwitchAccessoryView()
      accessoryView.configuration = configuration
      return accessoryView
    }
  }
}

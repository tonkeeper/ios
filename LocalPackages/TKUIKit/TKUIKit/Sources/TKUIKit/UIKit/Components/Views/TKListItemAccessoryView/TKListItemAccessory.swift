import UIKit

public enum TKListItemAccessory {
    case chevron
    case icon(TKListItemIconAccessoryView.Configuration)
    case text(TKListItemTextAccessoryView.Configuration)
    case `switch`(TKListItemSwitchAccessoryView.Configuration)
    case button(TKListItemButtonAccessoryView.Configuration)
    case radioButton(TKListItemRadioButtonAccessoryView.Configuration)

    public var view: UIView {
        switch self {
        case .chevron:
            let accessoryView = TKListItemIconAccessoryView()
            accessoryView.configuration = .chevron
            return accessoryView
        case let .icon(configuration):
            let accessoryView = TKListItemIconAccessoryView()
            accessoryView.configuration = configuration
            return accessoryView
        case let .text(configuration):
            let accessoryView = TKListItemTextAccessoryView()
            accessoryView.configuration = configuration
            return accessoryView
        case let .switch(configuration):
            let accessoryView = TKListItemSwitchAccessoryView()
            accessoryView.configuration = configuration
            return accessoryView
        case let .button(configuration):
            let view = TKListItemButtonAccessoryView()
            view.configuration = configuration
            return view
        case let .radioButton(configuration):
            let view = TKListItemRadioButtonAccessoryView()
            view.configuration = configuration
            return view
        }
    }
}

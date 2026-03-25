import Foundation
import TKUIKit
import UIKit

enum SettingsListSection: Hashable {
    case listItems(SettingsListItemsSection)
    case appInformation(SettingsAppInformationCell.Configuration)
    case button(SettingsButtonListItem)
}

enum SettingsListItemsSectionItem: Hashable {
    case listItem(SettingsListItem)
    case notificationBanner(SettingsNotificationBannerListItem)
    case button(SettingsButtonListItem)
}

struct SettingsListItemsSection: Hashable {
    let items: [SettingsListItemsSectionItem]
    let headerConfiguration: SettingsListSectionHeaderView.Configuration?
    let footerConfiguration: SettingsListSectionFooterView.Configuration?

    init(
        items: [SettingsListItemsSectionItem],
        headerConfiguration: SettingsListSectionHeaderView.Configuration? = nil,
        footerConfiguration: SettingsListSectionFooterView.Configuration? = nil
    ) {
        self.items = items
        self.headerConfiguration = headerConfiguration
        self.footerConfiguration = footerConfiguration
    }
}

class SettingsListItem: Hashable {
    let id: String
    let cellConfiguration: TKListItemCell.Configuration
    let accessory: TKListItemAccessory?
    let selectAccessory: TKListItemAccessory?
    let onSelection: ((UIView?) -> Void)?

    static func == (lhs: SettingsListItem, rhs: SettingsListItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    init(
        id: String,
        cellConfiguration: TKListItemCell.Configuration,
        accessory: TKListItemAccessory? = nil,
        selectAccessory: TKListItemAccessory? = nil,
        onSelection: ((UIView?) -> Void)?
    ) {
        self.id = id
        self.cellConfiguration = cellConfiguration
        self.accessory = accessory
        self.selectAccessory = selectAccessory
        self.onSelection = onSelection
    }
}

class SettingsButtonListItem: Hashable {
    let id: String
    let cellConfiguration: TKButtonCollectionViewCell.Configuration

    static func == (lhs: SettingsButtonListItem, rhs: SettingsButtonListItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    init(
        id: String,
        cellConfiguration: TKButtonCollectionViewCell.Configuration
    ) {
        self.id = id
        self.cellConfiguration = cellConfiguration
    }
}

class SettingsNotificationBannerListItem: Hashable {
    let id: String
    let cellConfiguration: NotificationBannerCell.Configuration

    static func == (lhs: SettingsNotificationBannerListItem, rhs: SettingsNotificationBannerListItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    init(
        id: String,
        cellConfiguration: NotificationBannerCell.Configuration
    ) {
        self.id = id
        self.cellConfiguration = cellConfiguration
    }
}

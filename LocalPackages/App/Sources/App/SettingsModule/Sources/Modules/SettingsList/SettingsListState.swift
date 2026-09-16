import Foundation
import SwiftUI
import TKUIKit
import UIKit

struct SettingsListState {
    let sections: [SettingsListSection]
}

enum SettingsListSection {
    case items(SettingsListItemsSection)
    case appInformation(SettingsListAppInformation)
}

struct SettingsListItemsSection {
    let items: [SettingsListItemsSectionItem]
    let header: SettingsListSectionHeader?
    let footer: String?

    init(
        items: [SettingsListItemsSectionItem],
        header: SettingsListSectionHeader? = nil,
        footer: String? = nil
    ) {
        self.items = items
        self.header = header
        self.footer = footer
    }
}

struct SettingsListSectionHeader {
    let title: String
    let caption: String?

    init(title: String, caption: String? = nil) {
        self.title = title
        self.caption = caption
    }
}

enum SettingsListItemsSectionItem {
    case listItem(SettingsListItem)
    case banner(SettingsListBannerItem)
    case button(SettingsListButtonItem)
}

struct SettingsListItem {
    let id: String
    let icon: SettingsListItemIcon?
    let title: SettingsListItemTitle
    let titleColor: TKColor
    let inlineCaption: String?
    let tags: [TKTagSwiftUIViewConfig]
    let redDotColor: TKColor?
    let captions: [SettingsListItemCaption]
    let accessory: SettingsListItemAccessory
    let onTap: (@MainActor (_ anchorView: UIView?) -> Void)?

    init(
        id: String,
        icon: SettingsListItemIcon? = nil,
        title: SettingsListItemTitle,
        titleColor: TKColor = .textPrimary,
        inlineCaption: String? = nil,
        tags: [TKTagSwiftUIViewConfig] = [],
        redDotColor: TKColor? = nil,
        captions: [SettingsListItemCaption] = [],
        accessory: SettingsListItemAccessory = .none,
        onTap: (@MainActor (_ anchorView: UIView?) -> Void)? = nil
    ) {
        self.id = id
        self.icon = icon
        self.title = title
        self.titleColor = titleColor
        self.inlineCaption = inlineCaption
        self.tags = tags
        self.redDotColor = redDotColor
        self.captions = captions
        self.accessory = accessory
        self.onTap = onTap
    }
}

struct SettingsListItemTitle {
    enum Part {
        case text(String)
        case icon(SwiftUI.Image)
    }

    let parts: [Part]

    init(parts: [Part]) {
        self.parts = parts
    }

    init(_ text: String) {
        parts = [.text(text)]
    }
}

struct SettingsListItemCaption {
    let text: String
    let color: TKColor
    let lineLimit: Int?

    init(_ text: String, color: TKColor = .textSecondary, lineLimit: Int? = nil) {
        self.text = text
        self.color = color
        self.lineLimit = lineLimit
    }
}

enum SettingsListItemIcon {
    case emoji(String, backgroundColor: TKColor)
    case image(SettingsListItemImageIcon)
    case url(URL?)
}

struct SettingsListItemImageIcon {
    let image: SwiftUI.Image
    let tintColor: TKColor
    let backgroundColor: TKColor
    let imageSize: CGSize

    init(
        image: SwiftUI.Image,
        tintColor: TKColor,
        backgroundColor: TKColor,
        imageSize: CGSize = CGSize(width: 24, height: 24)
    ) {
        self.image = image
        self.tintColor = tintColor
        self.backgroundColor = backgroundColor
        self.imageSize = imageSize
    }
}

enum SettingsListItemAccessory {
    case none
    case chevron
    case icon(UIImage, tintColor: TKColor)
    case text(SettingsListItemTextAccessory)
    case menu(SettingsListItemMenuAccessory)
    case toggle(SettingsListItemToggleAccessory)
}

struct SettingsListItemTextAccessory {
    let text: String
    let color: TKColor
    let textStyle: TKTextStyle
    let lineLimit: Int

    init(
        text: String,
        color: TKColor = .textPrimary,
        textStyle: TKTextStyle = .body2,
        lineLimit: Int = 1
    ) {
        self.text = text
        self.color = color
        self.textStyle = textStyle
        self.lineLimit = lineLimit
    }
}

struct SettingsListItemMenuAccessory {
    let label: SettingsListItemTextAccessory
    let options: [SettingsListItemMenuOption]
}

struct SettingsListItemMenuOption {
    let title: String
    let isSelected: Bool
    let action: () -> Void
}

struct SettingsListItemToggleAccessory {
    let isOn: Bool
    let isEnabled: Bool
    let onToggle: (Bool) -> Void

    init(
        isOn: Bool,
        isEnabled: Bool = true,
        onToggle: @escaping (Bool) -> Void
    ) {
        self.isOn = isOn
        self.isEnabled = isEnabled
        self.onToggle = onToggle
    }
}

struct SettingsListBannerItem {
    let id: String
    let content: NotificationBannerContent
    let onButtonTap: (() -> Void)?

    init(
        id: String,
        content: NotificationBannerContent,
        onButtonTap: (() -> Void)? = nil
    ) {
        self.id = id
        self.content = content
        self.onButtonTap = onButtonTap
    }
}

struct SettingsListButtonItem {
    let id: String
    let title: String
    let appearance: ButtonView.Appearance
    let action: () -> Void
}

struct SettingsListAppInformation {
    let appName: String
    let version: String
}

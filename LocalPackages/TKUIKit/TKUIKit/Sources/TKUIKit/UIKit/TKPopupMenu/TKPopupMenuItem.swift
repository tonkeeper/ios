import UIKit

public struct TKPopupMenuItem {
    public var title: String
    public var value: String?
    public var description: String?
    public var icon: UIImage?
    public var leftIcon: TKImageView.Model?
    public var footerText: String?
    public var footerActionTitle: String?
    public var footerActionHandler: (() -> Void)?
    /// A divider under the item. On Liquid Glass it is not used: every item but the last has one,
    /// as the design system draws the menu.
    public var hasSeparator: Bool
    public var isEnabled: Bool
    public var selectionHandler: (() -> Void)?

    public init(
        title: String,
        value: String? = nil,
        description: String? = nil,
        icon: UIImage? = nil,
        leftIcon: TKImageView.Model? = nil,
        footerText: String? = nil,
        footerActionTitle: String? = nil,
        footerActionHandler: (() -> Void)? = nil,
        hasSeparator: Bool = false,
        isEnabled: Bool = true,
        selectionHandler: (() -> Void)?
    ) {
        self.title = title
        self.value = value
        self.description = description
        self.icon = icon
        self.leftIcon = leftIcon
        self.footerText = footerText
        self.footerActionTitle = footerActionTitle
        self.footerActionHandler = footerActionHandler
        self.hasSeparator = hasSeparator
        self.isEnabled = isEnabled
        self.selectionHandler = selectionHandler
    }
}

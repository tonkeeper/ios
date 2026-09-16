import Foundation
import TKUIKit

public struct NFTDetailsScreenState {
    public struct Header {
        public enum LeftButton {
            case back
            case swipeDown
        }

        public struct Caption {
            public let title: String
            public let color: TKColor
            public let action: () -> Void

            public init(
                title: String,
                color: TKColor,
                action: @escaping () -> Void
            ) {
                self.title = title
                self.color = color
                self.action = action
            }
        }

        public let title: String
        public let leftButton: LeftButton
        public let caption: Caption?
        public let menuItems: [TKPopupMenuItem]

        public init(
            title: String,
            leftButton: LeftButton,
            caption: Caption? = nil,
            menuItems: [TKPopupMenuItem] = []
        ) {
            self.title = title
            self.leftButton = leftButton
            self.caption = caption
            self.menuItems = menuItems
        }
    }

    public struct SpamActions {
        public let reportSpamTitle: String
        public let notSpamTitle: String
        public let onReportSpam: () -> Void
        public let onNotSpam: () -> Void

        public init(
            reportSpamTitle: String,
            notSpamTitle: String,
            onReportSpam: @escaping () -> Void,
            onNotSpam: @escaping () -> Void
        ) {
            self.reportSpamTitle = reportSpamTitle
            self.notSpamTitle = notSpamTitle
            self.onReportSpam = onReportSpam
            self.onNotSpam = onNotSpam
        }
    }

    public struct Information {
        public struct CollectionSection {
            public let title: String
            public let description: String?

            public init(title: String, description: String?) {
                self.title = title
                self.description = description
            }
        }

        public let imageSource: NFTImageViewImageSource
        public let lottieURL: URL?
        public let isBlurred: Bool
        public let isOnSale: Bool
        public let name: String
        public let collectionName: String
        public let isCollectionVerified: Bool
        public let description: String?
        public let collectionSection: CollectionSection?
        public let moreTitle: String

        public init(
            imageSource: NFTImageViewImageSource,
            lottieURL: URL? = nil,
            isBlurred: Bool = false,
            isOnSale: Bool = false,
            name: String,
            collectionName: String,
            isCollectionVerified: Bool,
            description: String?,
            collectionSection: CollectionSection? = nil,
            moreTitle: String
        ) {
            self.imageSource = imageSource
            self.lottieURL = lottieURL
            self.isBlurred = isBlurred
            self.isOnSale = isOnSale
            self.name = name
            self.collectionName = collectionName
            self.isCollectionVerified = isCollectionVerified
            self.description = description
            self.collectionSection = collectionSection
            self.moreTitle = moreTitle
        }
    }

    public struct Button: Identifiable {
        public let id: String
        public let title: String
        public let appearance: ButtonView.Appearance
        public let icon: ButtonView.Icon?
        public let isEnabled: Bool
        public let showsLoader: Bool
        public let description: String?
        public let action: () -> Void

        public init(
            id: String,
            title: String,
            appearance: ButtonView.Appearance,
            icon: ButtonView.Icon? = nil,
            isEnabled: Bool = true,
            showsLoader: Bool = false,
            description: String? = nil,
            action: @escaping () -> Void
        ) {
            self.id = id
            self.title = title
            self.appearance = appearance
            self.icon = icon
            self.isEnabled = isEnabled
            self.showsLoader = showsLoader
            self.description = description
            self.action = action
        }
    }

    public struct Properties {
        public struct Property: Identifiable {
            public let id: String
            public let title: String
            public let value: String

            public init(id: String, title: String, value: String) {
                self.id = id
                self.title = title
                self.value = value
            }
        }

        public let title: String
        public let properties: [Property]

        public init(title: String, properties: [Property]) {
            self.title = title
            self.properties = properties
        }
    }

    public struct Details {
        public struct Item: Identifiable {
            public let id: String
            public let title: String
            public let value: String
            public let copyValue: String?

            public init(
                id: String,
                title: String,
                value: String,
                copyValue: String? = nil
            ) {
                self.id = id
                self.title = title
                self.value = value
                self.copyValue = copyValue
            }
        }

        public let title: String
        public let explorerButtonTitle: String
        public let items: [Item]
        public let onOpenExplorer: () -> Void

        public init(
            title: String,
            explorerButtonTitle: String,
            items: [Item],
            onOpenExplorer: @escaping () -> Void
        ) {
            self.title = title
            self.explorerButtonTitle = explorerButtonTitle
            self.items = items
            self.onOpenExplorer = onOpenExplorer
        }
    }

    public let header: Header
    public let spamActions: SpamActions?
    public let information: Information
    public let buttons: [Button]
    public let properties: Properties?
    public let details: Details

    public init(
        header: Header,
        spamActions: SpamActions? = nil,
        information: Information,
        buttons: [Button] = [],
        properties: Properties? = nil,
        details: Details
    ) {
        self.header = header
        self.spamActions = spamActions
        self.information = information
        self.buttons = buttons
        self.properties = properties
        self.details = details
    }
}

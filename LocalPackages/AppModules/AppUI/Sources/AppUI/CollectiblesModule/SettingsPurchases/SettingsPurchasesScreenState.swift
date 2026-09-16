import Foundation
import UIKit

public struct SettingsPurchasesScreenState {
    public struct ShowAllButton {
        public let title: String
        public let action: () -> Void

        public init(
            title: String,
            action: @escaping () -> Void
        ) {
            self.title = title
            self.action = action
        }
    }

    public struct Item: Identifiable {
        public enum Image {
            case url(URL?)
            case icon(UIImage)
        }

        public struct Control {
            public enum Kind {
                case hide
                case show
            }

            public let kind: Kind
            public let action: () -> Void

            public init(
                kind: Kind,
                action: @escaping () -> Void
            ) {
                self.kind = kind
                self.action = action
            }
        }

        public let id: String
        public let image: Image
        public let title: String
        public let subtitle: String
        public let control: Control?
        public let showsChevron: Bool
        public let action: () -> Void

        public init(
            id: String,
            image: Image,
            title: String,
            subtitle: String,
            control: Control? = nil,
            showsChevron: Bool = false,
            action: @escaping () -> Void
        ) {
            self.id = id
            self.image = image
            self.title = title
            self.subtitle = subtitle
            self.control = control
            self.showsChevron = showsChevron
            self.action = action
        }
    }

    public struct Section: Identifiable {
        public let id: String
        public let title: String
        public let items: [Item]
        public let showAllButton: ShowAllButton?

        public init(
            id: String,
            title: String,
            items: [Item],
            showAllButton: ShowAllButton? = nil
        ) {
            self.id = id
            self.title = title
            self.items = items
            self.showAllButton = showAllButton
        }
    }

    public let title: String
    public let sections: [Section]
    public let details: PurchasesManagementDetailsPresentation?
    public let onDismissDetails: () -> Void

    public init(
        title: String,
        sections: [Section],
        details: PurchasesManagementDetailsPresentation? = nil,
        onDismissDetails: @escaping () -> Void = {}
    ) {
        self.title = title
        self.sections = sections
        self.details = details
        self.onDismissDetails = onDismissDetails
    }
}

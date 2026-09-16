import UIKit

public struct RecoveryPhraseScreenState {
    public struct Word: Identifiable {
        public let index: Int
        public let value: String

        public var id: Int {
            index
        }

        public init(index: Int, value: String) {
            self.index = index
            self.value = value
        }
    }

    public struct Action: Identifiable {
        public enum Style {
            case primary
            case secondary
        }

        public let id: String
        public let title: String
        public let icon: UIImage?
        public let style: Style

        public init(
            id: String,
            title: String,
            icon: UIImage? = nil,
            style: Style
        ) {
            self.id = id
            self.title = title
            self.icon = icon
            self.style = style
        }
    }

    public let title: String
    public let caption: String
    public let banner: String?
    public let words: [Word]
    public let actions: [Action]

    public init(
        title: String,
        caption: String,
        banner: String? = nil,
        words: [Word],
        actions: [Action]
    ) {
        self.title = title
        self.caption = caption
        self.banner = banner
        self.words = words
        self.actions = actions
    }
}

import TKUIKit
import UIKit

public struct StoriesPageModel {
    public struct Button {
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

    public struct Link {
        public let text: String
        public let action: () -> Void

        public init(
            text: String,
            action: @escaping () -> Void
        ) {
            self.text = text
            self.action = action
        }
    }

    public let title: String
    public let description: String
    public let button: Button?
    public let links: [Link]
    public let backgroundImage: TKImage

    public init(
        title: String,
        description: String,
        button: Button? = nil,
        links: [Link] = [],
        backgroundImage: TKImage
    ) {
        self.title = title
        self.description = description
        self.button = button
        self.links = links
        self.backgroundImage = backgroundImage
    }
}

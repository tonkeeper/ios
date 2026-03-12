import Foundation
import KeeperCore

public struct Story: Decodable, Equatable {
    public struct Page: Decodable, Equatable {
        public struct Button: Decodable, Equatable {
            public enum ButtonType: String, Decodable {
                case deeplink
                case link
            }

            public let title: String
            public let payload: String
            public let type: ButtonType
        }

        public let title: String
        public let description: String
        public let image: URL?
        public let button: Button?
    }

    public let id: String
    public let pages: [Page]

    public init(id: String, story: KeeperCore.Story) {
        self.id = id
        self.pages = story.pages.map { Story.Page(page: $0) }
    }
}

extension Story.Page.Button.ButtonType {
    init(buttonType: KeeperCore.Story.Page.Button.ButtonType) {
        switch buttonType {
        case .deeplink:
            self = .deeplink
        case .link:
            self = .link
        }
    }
}

extension Story.Page.Button {
    init(button: KeeperCore.Story.Page.Button) {
        self.title = button.title
        self.payload = button.payload
        self.type = Story.Page.Button.ButtonType(buttonType: button.type)
    }
}

extension Story.Page {
    init(page: KeeperCore.Story.Page) {
        self.title = page.title
        self.description = page.description
        self.image = page.image
        self.button = {
            if let pageButton = page.button {
                return Story.Page.Button(button: pageButton)
            } else {
                return nil
            }
        }()
    }
}

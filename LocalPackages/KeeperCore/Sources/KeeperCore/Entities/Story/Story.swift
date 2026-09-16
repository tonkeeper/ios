import Foundation

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

            enum CodingKeys: String, CodingKey {
                case title
                case payload
                case type
            }

            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)

                title = try container.decode(String.self, forKey: .title)
                payload = try container.decode(String.self, forKey: .payload)

                let typeString = try container.decode(String.self, forKey: .type)
                guard let buttonType = ButtonType(rawValue: typeString) else {
                    throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Invalid button type")
                }

                type = buttonType
            }
        }

        public let title: String
        public let description: String
        public let image: URL?
        public let button: Button?
    }

    public struct MainScreen: Decodable, Equatable {
        public let title: String
        public let description: String
        public let icon: URL
    }

    public let story_id: String
    public let preview: URL
    public let main_screen: MainScreen
    public let pages: [Page]
    public let isAutoShow: Bool

    enum CodingKeys: String, CodingKey {
        case story_id
        case preview
        case main_screen
        case pages
        case isAutoShow = "is_auto_show"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        story_id = try container.decode(String.self, forKey: .story_id)
        preview = try container.decode(URL.self, forKey: .preview)
        main_screen = try container.decode(MainScreen.self, forKey: .main_screen)
        pages = try container.decode([Page].self, forKey: .pages)
        isAutoShow = try container.decodeIfPresent(Bool.self, forKey: .isAutoShow) ?? false
    }
}

struct StoriesResponse: Decodable, Equatable {
    let stories: [Story]
}

import Foundation

public struct HomeBanner: Codable, Equatable, Hashable, Identifiable {
    public let id: String
    public let title: String
    public let description: String
    public let image: URL?
    public let textColor: String?
    public let backgroundColor: String?
    public let button: Button?

    public init(
        id: String,
        title: String,
        description: String,
        image: URL?,
        textColor: String?,
        backgroundColor: String?,
        button: Button?
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.image = image
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.button = button
    }

    public struct Button: Codable, Equatable, Hashable {
        public enum ButtonType: Equatable, Hashable {
            case deeplink(URL)
            case link(URL)
            case unknown
        }

        public let title: String
        public let type: ButtonType

        enum CodingKeys: String, CodingKey {
            case type
            case payload
            case title
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            title = try container.decode(String.self, forKey: .title)
            let typeRaw = try container.decodeIfPresent(String.self, forKey: .type)
            let payload = try container.decodeIfPresent(String.self, forKey: .payload)

            switch typeRaw {
            case "deeplink":
                if let payload, let url = URL(string: payload) {
                    type = .deeplink(url)
                } else {
                    type = .unknown
                }
            case "link":
                if let payload, let url = URL(string: payload) {
                    type = .link(url)
                } else {
                    type = .unknown
                }
            default:
                type = .unknown
            }
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(title, forKey: .title)
            switch type {
            case let .deeplink(url):
                try container.encode("deeplink", forKey: .type)
                try container.encode(url.absoluteString, forKey: .payload)
            case let .link(url):
                try container.encode("link", forKey: .type)
                try container.encode(url.absoluteString, forKey: .payload)
            case .unknown:
                break
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case image
        case textColor
        case backgroundColor
        case button
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        image = try container.decodeIfPresent(String.self, forKey: .image).flatMap(URL.init(string:))
        textColor = try container.decodeIfPresent(String.self, forKey: .textColor)
        backgroundColor = try container.decodeIfPresent(String.self, forKey: .backgroundColor)
        button = try container.decodeIfPresent(Button.self, forKey: .button)
    }
}

struct HomeBannersResponse: Decodable {
    let banners: [HomeBanner]
}

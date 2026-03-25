import Foundation

public struct PopularAppsCategory: Codable {
    public let id: String
    public let title: String?
    public let apps: [PopularApp]
}

public struct PopularApps: Codable {
    public let categories: [PopularAppsCategory]
    public let apps: [PopularApp]
}

public struct PopularApp: Codable, Identifiable, Equatable {
    public let id: String
    public let name: String
    public let description: String?
    public let icon: URL?
    public let poster: URL?
    public let url: URL?
    public let textColor: String?
    public let excludeCountries: [String]?
    public let includeCountries: [String]?
    public let button: Button?

    public init(
        id: String,
        name: String,
        description: String?,
        icon: URL?,
        poster: URL?,
        url: URL?,
        textColor: String?,
        excludeCountries: [String]?,
        includeCountries: [String]?,
        button: Button?
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.poster = poster
        self.url = url
        self.textColor = textColor
        self.excludeCountries = excludeCountries
        self.includeCountries = includeCountries
        self.button = button
    }

    public struct Button: Codable, Equatable {
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
            let type = try container.decodeIfPresent(String.self, forKey: .type)
            switch type {
            case "deeplink":
                if let payload = try container.decodeIfPresent(String.self, forKey: .payload),
                   let url = URL(string: payload)
                {
                    self.type = .deeplink(url)
                } else {
                    self.type = .unknown
                }
            default:
                self.type = .unknown
            }
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(title, forKey: .title)
            switch type {
            case let .deeplink(url):
                try container.encode(url.absoluteString, forKey: .payload)
                try container.encode("deeplink", forKey: .type)
            case .unknown:
                break
            }
        }
    }

    public enum ButtonType: Equatable {
        case deeplink(URL)
        case unknown
    }
}

public struct PopularAppsResponseData: Codable {
    public let moreEnabled: Bool
    public let apps: [PopularApp]
    public let categories: [PopularAppsCategory]

    public static var empty: PopularAppsResponseData {
        PopularAppsResponseData(
            moreEnabled: false,
            apps: [],
            categories: []
        )
    }
}

public struct PopularAppsResponse: Codable {
    public let data: PopularAppsResponseData
}

public extension PopularAppsResponseData {
    var defiCategory: PopularAppsCategory? {
        categories.first(where: { $0.id == "defi" })
    }
}

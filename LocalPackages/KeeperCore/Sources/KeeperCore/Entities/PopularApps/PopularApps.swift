import Foundation

public struct PopularAppsCategory: Codable {
    public let id: String
    public let title: String?
    public let apps: [PopularApp]
}

public struct PopularApp: Codable, Identifiable, Equatable {
    public let id: String
    public let bannerId: String?
    public let name: String
    public let description: String?
    public let icon: URL?
    public let poster: URL?
    public let url: URL?
    public let textColor: String?
    public let excludeCountries: [String]?
    public let includeCountries: [String]?
    public let button: Button?
    public let chains: [MultichainChain]

    public init(
        id: String,
        bannerId: String? = nil,
        name: String,
        description: String?,
        icon: URL?,
        poster: URL?,
        url: URL?,
        textColor: String?,
        excludeCountries: [String]?,
        includeCountries: [String]?,
        button: Button?,
        chains: [MultichainChain] = []
    ) {
        self.id = id
        self.bannerId = bannerId
        self.name = name
        self.description = description
        self.icon = icon
        self.poster = poster
        self.url = url
        self.textColor = textColor
        self.excludeCountries = excludeCountries
        self.includeCountries = includeCountries
        self.button = button
        self.chains = chains
    }

    public struct Button: Codable, Equatable {
        public let title: String
        public let type: ButtonType

        public init(title: String, type: ButtonType) {
            self.title = title
            self.type = type
        }

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

public extension PopularAppsResponseData {
    var defiCategory: PopularAppsCategory? {
        categories.first(where: { $0.id == "defi" })
    }
}

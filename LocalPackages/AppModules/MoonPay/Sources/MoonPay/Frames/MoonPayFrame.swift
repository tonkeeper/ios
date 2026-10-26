import Foundation

/// A MoonPay Platform frame together with the parameters it is opened with.
/// Paths and parameter names follow https://dev.moonpay.com/platform/frames.
public enum MoonPayFrame: Equatable, Sendable {
    case checkConnection(sessionToken: String, publicKeyHex: String, skipKyc: Bool? = nil)
    case connect(clientToken: String, publicKeyHex: String, theme: MoonPayTheme? = nil)
    case widget(clientToken: String, quoteSignature: String, externalTransactionId: String? = nil, theme: MoonPayTheme? = nil)
    case buy(clientToken: String, signature: String, externalTransactionId: String? = nil)
    case applePay(
        clientToken: String,
        signature: String,
        externalTransactionId: String? = nil,
        theme: MoonPayTheme? = nil,
        applePayButtonSettings: String? = nil
    )
    case addCard(clientToken: String, theme: MoonPayTheme? = nil)
    /// The challenge URL is issued by MoonPay (a quote response or a `challenge` event) and is only
    /// ever extended with query parameters, never rebuilt.
    case challenge(url: URL, clientToken: String, theme: MoonPayTheme? = nil)

    public var name: String {
        switch self {
        case .checkConnection: "checkConnection"
        case .connect: "connect"
        case .widget: "widget"
        case .buy: "buy"
        case .applePay: "applePay"
        case .addCard: "addCard"
        case .challenge: "challenge"
        }
    }

    /// `nil` for `.challenge`, whose path comes with the URL MoonPay issued.
    public var path: String? {
        switch self {
        case .checkConnection: "/platform/v1/check-connection"
        case .connect: "/platform/v1/connect"
        case .widget: "/platform/v1/widget"
        case .buy: "/platform/v1/buy"
        case .applePay: "/platform/v1/apple-pay"
        case .addCard: "/platform/v1/add-card"
        case .challenge: nil
        }
    }

    public func queryItems(channelId: String) -> [URLQueryItem] {
        var items: [URLQueryItem] = []
        func add(_ name: String, _ value: String?) {
            guard let value else { return }
            items.append(URLQueryItem(name: name, value: value))
        }
        switch self {
        case let .checkConnection(sessionToken, publicKeyHex, skipKyc):
            add("sessionToken", sessionToken)
            add("publicKey", publicKeyHex)
            add("skipKyc", skipKyc.map { $0 ? "true" : "false" })
        case let .connect(clientToken, publicKeyHex, theme):
            add("clientToken", clientToken)
            add("publicKey", publicKeyHex)
            add("theme", theme?.rawValue)
        case let .widget(clientToken, quoteSignature, externalTransactionId, theme):
            add("flow", "buy")
            add("clientToken", clientToken)
            add("quoteSignature", quoteSignature)
            add("externalTransactionId", externalTransactionId)
            add("theme", theme?.rawValue)
        case let .buy(clientToken, signature, externalTransactionId):
            add("clientToken", clientToken)
            add("signature", signature)
            add("externalTransactionId", externalTransactionId)
        case let .applePay(clientToken, signature, externalTransactionId, theme, applePayButtonSettings):
            add("clientToken", clientToken)
            add("signature", signature)
            add("externalTransactionId", externalTransactionId)
            add("theme", theme?.rawValue)
            add("applePayButtonSettings", applePayButtonSettings)
        case let .addCard(clientToken, theme):
            add("clientToken", clientToken)
            add("theme", theme?.rawValue)
        case let .challenge(_, clientToken, theme):
            add("clientToken", clientToken)
            add("theme", theme?.rawValue)
        }
        add("channelId", channelId)
        return items
    }

    public func url(environment: MoonPayEnvironment, channelId: String) throws -> URL {
        var components: URLComponents
        switch self {
        case let .challenge(url, _, _):
            guard let challengeComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                throw MoonPayFrameError.invalidURL
            }
            components = challengeComponents
        default:
            guard let path,
                  var originComponents = URLComponents(url: environment.frameOrigin, resolvingAgainstBaseURL: false)
            else {
                throw MoonPayFrameError.invalidURL
            }
            originComponents.path = path
            components = originComponents
        }
        let existingItems = components.percentEncodedQueryItems ?? []
        components.percentEncodedQueryItems = existingItems + queryItems(channelId: channelId).map(Self.percentEncoded)
        guard let url = components.url else { throw MoonPayFrameError.invalidURL }
        return url
    }

    /// Tokens and signatures may contain `+`, `/` and `=`, which `URLComponents` leaves as is and
    /// which some servers read as a space or a delimiter, so only RFC 3986 unreserved characters
    /// pass through unescaped.
    private static func percentEncoded(_ item: URLQueryItem) -> URLQueryItem {
        URLQueryItem(name: encode(item.name), value: item.value.map(encode))
    }

    private static let unreservedCharacters: CharacterSet = {
        var characters = CharacterSet.alphanumerics
        characters.insert(charactersIn: "-._~")
        return characters
    }()

    private static func encode(_ string: String) -> String {
        string.addingPercentEncoding(withAllowedCharacters: unreservedCharacters) ?? string
    }
}

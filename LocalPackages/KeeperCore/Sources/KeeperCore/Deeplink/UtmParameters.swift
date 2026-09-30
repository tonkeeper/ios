import Foundation

/// Campaign tags a link carries. `Deeplink` keeps no trace of the original string, so they have to be
/// read from the link itself, beside `DeeplinkParser.parse`.
public struct UtmParameters: Equatable, Sendable {
    public static let empty = UtmParameters()

    public static var queryItemNames: [String] {
        QueryItem.allCases.map(\.rawValue)
    }

    public let source: String?
    public let medium: String?
    public let campaign: String?
    public let term: String?
    public let content: String?

    public var isEmpty: Bool {
        source == nil && medium == nil && campaign == nil && term == nil && content == nil
    }

    public init(link: String?) {
        let queryItems = link.flatMap(Self.queryItems(of:)) ?? []
        func value(_ item: QueryItem) -> String? {
            guard let value = queryItems.first(where: { $0.name == item.rawValue })?.value?
                .trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty
            else { return nil }
            return value
        }
        source = value(.source)
        medium = value(.medium)
        campaign = value(.campaign)
        term = value(.term)
        content = value(.content)
    }

    private init() {
        source = nil
        medium = nil
        campaign = nil
        term = nil
        content = nil
    }

    enum QueryItem: String, CaseIterable {
        case source = "utm_source"
        case medium = "utm_medium"
        case campaign = "utm_campaign"
        case term = "utm_term"
        case content = "utm_content"
    }

    /// A link can reach the app percent-encoded once or twice — as the payload of another link, or after
    /// a redirect — and only the decoded form has a query to read.
    private static func queryItems(of link: String) -> [URLQueryItem]? {
        var candidate = link
        for _ in 0 ... 2 {
            if let queryItems = URLComponents(string: candidate)?.queryItems {
                return queryItems
            }
            guard let decoded = candidate.removingPercentEncoding, decoded != candidate else { break }
            candidate = decoded
        }
        return nil
    }
}

import Foundation

@frozen public enum SearchEngine: String, Codable, Equatable, CaseIterable {
    case duckduckgo = "DuckDuckGo"
    case google = "Google"
}

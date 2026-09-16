import Foundation

public extension KeeperInfo {
    struct AppSettings: Equatable {
        public let isSecureMode: Bool
        public let searchEngine: SearchEngine
        public let hidesDustTransactions: Bool
        public let hidesDustBalances: Bool

        public init(
            isSecureMode: Bool,
            searchEngine: SearchEngine,
            hidesDustTransactions: Bool = false,
            hidesDustBalances: Bool = false
        ) {
            self.isSecureMode = isSecureMode
            self.searchEngine = searchEngine
            self.hidesDustTransactions = hidesDustTransactions
            self.hidesDustBalances = hidesDustBalances
        }

        public func updating(
            isSecureMode: Bool? = nil,
            searchEngine: SearchEngine? = nil,
            hidesDustTransactions: Bool? = nil,
            hidesDustBalances: Bool? = nil
        ) -> AppSettings {
            AppSettings(
                isSecureMode: isSecureMode ?? self.isSecureMode,
                searchEngine: searchEngine ?? self.searchEngine,
                hidesDustTransactions: hidesDustTransactions ?? self.hidesDustTransactions,
                hidesDustBalances: hidesDustBalances ?? self.hidesDustBalances
            )
        }
    }
}

extension KeeperInfo.AppSettings: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.isSecureMode = (try? container.decode(Bool.self, forKey: .isSecureMode)) ?? false
        if let selectedSearchEngine = try container.decodeIfPresent(SearchEngine.self, forKey: .searchEngine) {
            self.searchEngine = selectedSearchEngine
        } else {
            self.searchEngine = .duckduckgo
        }
        self.hidesDustTransactions = (try? container.decode(Bool.self, forKey: .hidesDustTransactions)) ?? false
        self.hidesDustBalances = (try? container.decode(Bool.self, forKey: .hidesDustBalances)) ?? false
    }
}

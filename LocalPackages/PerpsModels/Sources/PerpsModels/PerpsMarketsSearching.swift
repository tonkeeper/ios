public protocol PerpsMarketsSearching: AnyObject, Sendable {
    func markets(query: String?, sort: PerpsMarketsSort, cursor: String?, filter: PerpsMarketFilter) async throws -> PerpsMarketsPage
}

public extension PerpsMarketsSearching {
    func markets(query: String?, sort: PerpsMarketsSort, cursor: String?) async throws -> PerpsMarketsPage {
        try await markets(query: query, sort: sort, cursor: cursor, filter: .all)
    }
}

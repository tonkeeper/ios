public protocol PerpsMarketsSearching: AnyObject, Sendable {
    func markets(query: String?, sort: PerpsMarketsSort, cursor: String?) async throws -> PerpsMarketsPage
}

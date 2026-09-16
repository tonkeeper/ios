public struct MultichainSwapAssetsQuery: Sendable, Hashable {
    public var searchQuery: String?
    public var limit: Int?
    public var chain: String?

    public init(searchQuery: String? = nil, limit: Int? = nil, chain: String? = nil) {
        self.searchQuery = searchQuery
        self.limit = limit
        self.chain = chain
    }
}

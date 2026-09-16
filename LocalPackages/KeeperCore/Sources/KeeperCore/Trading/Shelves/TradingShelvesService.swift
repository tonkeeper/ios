public enum LoadShelvesFailure: Error {
    case networkError
    case apiError(
        message: String?
    )
}

public enum TradingShelvesMode: Hashable, Sendable {
    case legacy
    case multichain
}

public protocol TradingShelvesService {
    func shelves(for mode: TradingShelvesMode) async -> TradingShelvesSnapshot?

    func loadShelves(for mode: TradingShelvesMode) async throws(LoadShelvesFailure) -> TradingShelvesSnapshot
}

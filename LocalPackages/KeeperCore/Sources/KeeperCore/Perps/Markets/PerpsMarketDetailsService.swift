import Foundation

enum PerpsMarketDetailsLoadError: Error {
    case notFound
    case failed
}

protocol PerpsMarketDetailsLoading: AnyObject {
    func load(marketId: Int64) async throws -> PerpsAssetMarketSnapshot
}

final class PerpsMarketDetailsService: PerpsMarketDetailsLoading {
    private let repository: PerpsMarketsReading

    init(repository: PerpsMarketsReading) {
        self.repository = repository
    }

    func load(marketId: Int64) async throws -> PerpsAssetMarketSnapshot {
        do {
            return try PerpsAssetMarketSnapshot(details: await repository.reloadMarketDetails(marketId: marketId))
        } catch PerpsMarketsRepositoryError.marketNotFound {
            throw PerpsMarketDetailsLoadError.notFound
        } catch {
            throw PerpsMarketDetailsLoadError.failed
        }
    }
}

import Foundation

public protocol EarnAssetOffersRepository: Sendable {
    func offers(assetIds: [String]) async throws -> [String: EarnAssetOffer]
}

public extension EarnAssetOffersRepository {
    func offer(assetId: String) async throws -> EarnAssetOffer? {
        try await offers(assetIds: [assetId])[assetId]
    }
}

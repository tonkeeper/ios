import Foundation

struct HardcodedEarnAssetOffersRepository: EarnAssetOffersRepository {
    private let isEarnEnabled: Bool
    private let offers: [String: EarnAssetOffer]

    init(isEarnEnabled: Bool) {
        self.isEarnEnabled = isEarnEnabled
        offers = Dictionary(
            EarnHardcodedData.assetOffers.map { (Self.key(assetId: $0.assetId), $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    func offers(assetIds: [String]) async throws -> [String: EarnAssetOffer] {
        guard isEarnEnabled else { return [:] }
        return assetIds.reduce(into: [:]) { result, assetId in
            result[assetId] = offers[Self.key(assetId: assetId)]
        }
    }

    private static func key(assetId: String) -> String {
        assetId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

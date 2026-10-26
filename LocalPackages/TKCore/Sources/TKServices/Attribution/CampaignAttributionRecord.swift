import Foundation

public enum CampaignAttributionProvider: String, Codable, Sendable, CaseIterable {
    case branch
    case linkrunner
}

public struct CampaignAttributionRecord: Codable, Equatable, Sendable {
    public let provider: CampaignAttributionProvider
    public let payload: [String: AttributionJSON]
    public let resolvedDeeplink: String?
    public let capturedAt: Date

    public init(
        provider: CampaignAttributionProvider,
        payload: [String: AttributionJSON],
        resolvedDeeplink: String?,
        capturedAt: Date
    ) {
        self.provider = provider
        self.payload = payload
        self.resolvedDeeplink = resolvedDeeplink
        self.capturedAt = capturedAt
    }
}

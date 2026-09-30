public struct RedAnalyticsMetadataKey: ExpressibleByStringLiteral, Hashable {
    var rawValue: String

    public init(stringLiteral: String) {
        self.rawValue = stringLiteral
    }
}

public extension RedAnalyticsMetadataKey {
    static let amount: RedAnalyticsMetadataKey = "amount"
    static let asset: RedAnalyticsMetadataKey = "asset"
    static let appId: RedAnalyticsMetadataKey = "app_id"
    static let dappUrl: RedAnalyticsMetadataKey = "dapp_url"
    static let source: RedAnalyticsMetadataKey = "source"
    static let connectionType: RedAnalyticsMetadataKey = "connection_type"
    static let dappHost: RedAnalyticsMetadataKey = "dapp_host"
    static let feePaidIn: RedAnalyticsMetadataKey = "fee_paid_in"
    static let poolAddress: RedAnalyticsMetadataKey = "pool_address"
    static let poolKind: RedAnalyticsMetadataKey = "pool_kind"
}

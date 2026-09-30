public struct MultichainPendingTransaction: Sendable, Hashable {
    public struct SwapDetails: Sendable, Hashable {
        /// Absent for swaps the wallet routes itself, without a cross-chain quote.
        public struct QuoteAttribution: Sendable, Hashable {
            public let aggregator: String
            public let routeId: String
            public let providerRouteId: String?

            public init(aggregator: String, routeId: String, providerRouteId: String? = nil) {
                self.aggregator = aggregator
                self.routeId = routeId
                self.providerRouteId = providerRouteId
            }
        }

        public let fromAssetId: String
        public let toAssetId: String
        public let quote: QuoteAttribution?

        public init(
            fromAssetId: String,
            toAssetId: String,
            quote: QuoteAttribution? = nil
        ) {
            self.fromAssetId = fromAssetId
            self.toAssetId = toAssetId
            self.quote = quote
        }
    }

    public enum ActivityType: Sendable, Hashable {
        case send
        case swap(SwapDetails)
        case stake
        case unstake
        case contractCall

        public var name: String {
            switch self {
            case .send: "send"
            case .swap: "swap"
            case .stake: "stake"
            case .unstake: "unstake"
            case .contractCall: "contract_call"
            }
        }
    }

    public let walletId: String
    public let chain: MultichainChain
    public let network: MultichainNetwork
    public let txHash: String
    public let activityType: ActivityType

    public init(
        walletId: String,
        chain: MultichainChain,
        network: MultichainNetwork,
        txHash: String,
        activityType: ActivityType
    ) {
        self.walletId = walletId
        self.chain = chain
        self.network = network
        self.txHash = txHash
        self.activityType = activityType
    }
}

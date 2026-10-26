import ActivityKit
import Foundation

/// One activity per wallet that moves on from transaction to transaction, so everything about the
/// transaction it shows is content, not attributes.
@available(iOS 16.1, *)
struct TransactionLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        enum Kind: String, Codable {
            case send
            case receive
            case swap
            case other
        }

        struct Leg: Codable, Hashable {
            let network: String?
            let currency: String?
            let amount: String?
        }

        struct WalletDisplay: Codable, Hashable {
            let name: String
            let emoji: String?
            let icon: String?
        }

        enum Status: String, Codable {
            case pending
            case confirmed
            case failed
            case dropped
            case unknown
        }

        /// Where a multi-stage operation is, 1-based; the outcome is the last of `count`.
        struct Stage: Codable, Hashable {
            let index: Int
            let count: Int
        }

        var transactionId: String
        var chain: String
        var detail: String?
        let status: Status
        let title: String
        let updatedAt: Date
        let source: Leg?
        let destination: Leg?
        let kind: Kind?
        let wallet: WalletDisplay?
        let counterpartyAddress: String?
        let stage: Stage?
        /// The market of a perps trade, which a tap opens.
        let perpsMarketId: Int64?
    }

    let walletId: String
    private let transactionId: String?
    private let chain: String?
    private let detail: String?
}

@available(iOS 16.1, *)
extension TransactionLiveActivityAttributes {
    init(walletId: String) {
        self.init(walletId: walletId, transactionId: nil, chain: nil, detail: nil)
    }

    /// Older activities kept the transaction identity in their immutable attributes.
    func resolving(_ state: ContentState) -> ContentState {
        guard state.transactionId.isEmpty, let transactionId, let chain else { return state }
        var resolved = state
        resolved.transactionId = transactionId
        resolved.chain = chain
        resolved.detail = detail
        return resolved
    }
}

@available(iOS 16.1, *)
extension TransactionLiveActivityAttributes.ContentState {
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            transactionId: values.decodeIfPresent(String.self, forKey: .transactionId) ?? "",
            chain: values.decodeIfPresent(String.self, forKey: .chain) ?? "",
            detail: values.decodeIfPresent(String.self, forKey: .detail),
            status: values.decode(Status.self, forKey: .status),
            title: values.decode(String.self, forKey: .title),
            updatedAt: values.decode(Date.self, forKey: .updatedAt),
            source: values.decodeIfPresent(Leg.self, forKey: .source),
            destination: values.decodeIfPresent(Leg.self, forKey: .destination),
            kind: values.decodeIfPresent(Kind.self, forKey: .kind),
            wallet: values.decodeIfPresent(WalletDisplay.self, forKey: .wallet),
            counterpartyAddress: values.decodeIfPresent(String.self, forKey: .counterpartyAddress),
            stage: values.decodeIfPresent(Stage.self, forKey: .stage),
            perpsMarketId: values.decodeIfPresent(Int64.self, forKey: .perpsMarketId)
        )
    }
}

@available(iOS 16.2, *)
extension Activity where Attributes == TransactionLiveActivityAttributes {
    var transactionState: TransactionLiveActivityAttributes.ContentState {
        attributes.resolving(content.state)
    }
}

/// The URL a tap on the activity opens the app with. The app takes it before the deeplink parser,
/// so a transaction's ids never reach the attribution SDKs.
struct TransactionLiveActivityLink: Equatable {
    private static let scheme = "tonkeeper"
    private static let host = "live-activity"
    static let perpsFundingPrefix = "perps-funding:"

    let walletId: String
    let transactionId: String
    let perpsMarketId: Int64?

    init(walletId: String, transactionId: String, perpsMarketId: Int64? = nil) {
        self.walletId = walletId
        self.transactionId = transactionId
        self.perpsMarketId = perpsMarketId
    }

    init?(url: URL) {
        guard url.scheme == Self.scheme, url.host == Self.host,
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let walletId = items.first(where: { $0.name == "wallet_id" })?.value,
              let transactionId = items.first(where: { $0.name == "transaction_id" })?.value
        else {
            return nil
        }
        self.init(
            walletId: walletId,
            transactionId: transactionId,
            perpsMarketId: items.first(where: { $0.name == "market_id" })?.value.flatMap { Int64($0) }
        )
    }

    /// A perps deposit or withdrawal, which the perps history follows.
    var perpsFundingOperationId: String? {
        transactionId.hasPrefix(Self.perpsFundingPrefix)
            ? String(transactionId.dropFirst(Self.perpsFundingPrefix.count)) : nil
    }

    var url: URL? {
        var components = URLComponents()
        components.scheme = Self.scheme
        components.host = Self.host
        components.queryItems = [
            URLQueryItem(name: "wallet_id", value: walletId),
            URLQueryItem(name: "transaction_id", value: transactionId),
        ]
        if let perpsMarketId {
            components.queryItems?.append(URLQueryItem(name: "market_id", value: String(perpsMarketId)))
        }
        return components.url
    }
}

import Foundation
import TonSwift
import TronSwift

public struct FiatMethodItem: Codable, Equatable, Hashable {
    public typealias ID = String

    public struct Button: Codable, Equatable, Hashable {
        public let title: String
        public let url: String
    }

    public enum CodingKeys: String, CodingKey {
        case id
        case title
        case isDisabled = "disabled"
        case badge
        case subtitle
        case description
        case iconURL = "icon_url"
        case actionButton = "action_button"
        case infoButtons = "info_buttons"
    }

    public let id: ID
    public let title: String
    public let subtitle: String?
    public let isDisabled: Bool
    public let badge: String?
    public let description: String?
    public let iconURL: URL?
    public let actionButton: Button
    public let infoButtons: [Button]
}

public struct FiatMethodCategory: Codable, Equatable, Hashable {
    public enum Asset: String, Codable {
        case USDT
        case BTC
        case ETH
        case SOL
        case TON
        case BNB
        case XRP
        case ADA
        case NOT
    }

    public let type: String
    public let title: String?
    public let subtitle: String?
    public let items: [FiatMethodItem]
    public let assets: [Asset]

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
        items = try container.decode([FiatMethodItem].self, forKey: .items)

        var array = try container.nestedUnkeyedContainer(forKey: .assets)
        var assets = [Asset]()
        while !array.isAtEnd {
            let assetRaw = try array.decode(String.self)
            if let asset = Asset(rawValue: assetRaw) {
                assets.append(asset)
            }
        }
        self.assets = assets
    }
}

public struct FiatMethods: Codable, Equatable {
    public let categories: [FiatMethodCategory]
    public let buy: [FiatMethodCategory]
    public let sell: [FiatMethodCategory]
}

struct FiatMethodsResponse: Codable {
    let data: FiatMethods
}

public extension FiatMethodItem {
    struct ActionURLContext {
        public let url: URL
        public let transactionId: UUID?
    }

    struct MercuryoParameters {
        let secret: String?
        let ipProvider: () async -> String?
        public init(secret: String?, ipProvider: @escaping () async -> String?) {
            self.secret = secret
            self.ipProvider = ipProvider
        }
    }

    func actionURL(
        walletAddress: FriendlyAddress,
        tronAddress: TronSwift.Address?,
        currency: Currency,
        mercuryoParameters: MercuryoParameters
    ) async -> URL? {
        await actionURLContext(
            walletAddress: walletAddress,
            tronAddress: tronAddress,
            currency: currency,
            mercuryoParameters: mercuryoParameters
        )?.url
    }

    func actionURLContext(
        walletAddress: FriendlyAddress,
        tronAddress: TronSwift.Address?,
        currency: Currency,
        mercuryoParameters: MercuryoParameters
    ) async -> ActionURLContext? {
        let normalizedId = id.lowercased()
        let isSell = normalizedId.contains("sell")

        var urlString = actionButton.url
        let transactionIdQueryName = transactionIdQueryName
        let transactionId = transactionIdQueryName.map { _ in UUID() }
        let transactionIdValue = transactionId?.uuidString

        var signature: String?
        switch normalizedId {
        case _ where normalizedId.contains("mercuryo"):
            guard let transactionIdValue else { return nil }
            signature = await signatureForMercuryo(
                urlString: &urlString,
                isSell: isSell,
                walletAddress: walletAddress,
                transactionId: transactionIdValue,
                mercuryoParameters: mercuryoParameters
            )
        default:
            break
        }
        if isSell {
            urlString = urlString.replacingOccurrences(of: "{CUR_FROM}", with: "GRAM")
            urlString = urlString.replacingOccurrences(of: "{CUR_TO}", with: currency.code)
        } else {
            urlString = urlString.replacingOccurrences(of: "{CUR_FROM}", with: currency.code)
            urlString = urlString.replacingOccurrences(of: "{CUR_TO}", with: "GRAM")
        }

        urlString = urlString.replacingOccurrences(of: "{ADDRESS}", with: walletAddress.toString())
        urlString = urlString.replacingOccurrences(of: "{TRON_ADDRESS}", with: tronAddress?.base58 ?? "")

        guard var components = URLComponents(string: urlString) else { return nil }
        var queryItems = components.queryItems ?? []

        if let transactionIdQueryName, let transactionIdValue {
            upsertQueryItem(name: transactionIdQueryName, value: transactionIdValue, queryItems: &queryItems)
        }

        if let signature {
            upsertQueryItem(name: "signature", value: "v2:\(signature)", queryItems: &queryItems)
        }

        components.queryItems = queryItems

        guard let url = components.url else { return nil }
        return ActionURLContext(url: url, transactionId: transactionId)
    }

    private func signatureForMercuryo(
        urlString: inout String,
        isSell: Bool,
        walletAddress: FriendlyAddress,
        transactionId: String,
        mercuryoParameters: MercuryoParameters
    ) async -> String? {
        if isSell {
            urlString = urlString.replacingOccurrences(of: "{CUR_TO}", with: "GRAM")
        } else {
            urlString = urlString.replacingOccurrences(of: "{CUR_FROM}", with: "GRAM")
        }

        urlString = urlString.replacingOccurrences(of: "{TX_ID}", with: transactionId)

        let mercuryoSecret = mercuryoParameters.secret ?? ""
        let ip = await mercuryoParameters.ipProvider() ?? ""
        let signatureInput = walletAddress.toString() + mercuryoSecret + ip + transactionId
        return signatureInput.data(using: .utf8)?.sha512().hexString()
    }

    private func upsertQueryItem(name: String, value: String, queryItems: inout [URLQueryItem]) {
        if let index = queryItems.firstIndex(where: { $0.name == name }) {
            queryItems[index] = URLQueryItem(name: name, value: value)
        } else {
            queryItems.append(URLQueryItem(name: name, value: value))
        }
    }

    private var transactionIdQueryName: String? {
        switch id.lowercased() {
        case let id where id.contains("mercuryo"):
            "merchant_transaction_id"
        case let id where id.contains("moonpay"):
            "externalTransactionId"
        case let id where id.contains("transak"):
            "partnerOrderId"
        case let id where id.contains("changelly"):
            "payment_id"
        default:
            nil
        }
    }
}

extension Data {
    func hexString() -> String {
        map { String(format: "%02hhx", $0) }.joined()
    }
}

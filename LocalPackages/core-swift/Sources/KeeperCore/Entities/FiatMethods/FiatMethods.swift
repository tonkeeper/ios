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

public struct FiatMethodDefaultLayout: Codable, Equatable {
    public let methods: [FiatMethodItem.ID]
}

public struct FiatMethodLayoutByCountry: Codable, Equatable {
    public let countryCode: String
    public let currency: String
    public let methods: [FiatMethodItem.ID]
}

public struct FiatMethods: Codable, Equatable {
    public let categories: [FiatMethodCategory]
    public let buy: [FiatMethodCategory]
    public let sell: [FiatMethodCategory]
}

public struct FiatMethodsResponse: Codable {
    public let data: FiatMethods
}

public extension FiatMethodItem {
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
        let isSell = id.contains("sell")

        var urlString = actionButton.url

        switch id {
        case _ where id.contains("mercuryo"):
            await urlForMercuryo(
                urlString: &urlString,
                isSell: isSell,
                walletAddress: walletAddress,
                mercuryoParameters: mercuryoParameters
            )
        default:
            break
        }
        if isSell {
            urlString = urlString.replacingOccurrences(of: "{CUR_FROM}", with: "TONCOIN")
            urlString = urlString.replacingOccurrences(of: "{CUR_TO}", with: currency.code)
        } else {
            urlString = urlString.replacingOccurrences(of: "{CUR_FROM}", with: currency.code)
            urlString = urlString.replacingOccurrences(of: "{CUR_TO}", with: "TON")
        }

        urlString = urlString.replacingOccurrences(of: "{ADDRESS}", with: walletAddress.toString())
        urlString = urlString.replacingOccurrences(of: "{TRON_ADDRESS}", with: tronAddress?.base58 ?? "")
        guard let url = URL(string: urlString) else { return nil }
        return url
    }

    private func urlForMercuryo(
        urlString: inout String,
        isSell: Bool,
        walletAddress: FriendlyAddress,
        mercuryoParameters: MercuryoParameters
    ) async {
        if isSell {
            urlString = urlString.replacingOccurrences(of: "{CUR_TO}", with: "TONCOIN")
        } else {
            urlString = urlString.replacingOccurrences(of: "{CUR_FROM}", with: "TONCOIN")
        }

        let txId = "mercuryo_\(UUID().uuidString)"

        urlString = urlString.replacingOccurrences(of: "{TX_ID}", with: txId)

        let mercuryoSecret = mercuryoParameters.secret ?? ""
        let ip = await mercuryoParameters.ipProvider() ?? ""
        let signatureInput = walletAddress.toString() + mercuryoSecret + ip + txId
        guard let signature = signatureInput.data(using: .utf8)?.sha512().hexString() else { return }
        urlString += "&signature=v2:\(signature)"
    }
}

extension Data {
    func hexString() -> String {
        map { String(format: "%02hhx", $0) }.joined()
    }
}

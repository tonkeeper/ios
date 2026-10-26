import Foundation

public enum MoonPayAssetSource: String, Codable, Sendable {
    case cefi
    case defi
}

/// One entry of `GET /platform/v1/assets`. CeFi assets are quoted by `code`, which already carries
/// the network (`USDC_SOL`); DeFi tokens by `caip19`, because their `code` is not unique.
public struct MoonPayPlatformAsset: Decodable, Equatable, Sendable {
    public let caip19: String
    public let code: String
    public let name: String?
    public let network: String
    public let source: MoonPayAssetSource?
    /// `nil` for the native token of a network.
    public let contractAddress: String?
    public let decimals: Int?
    public let precision: Int?
    public let isAvailable: Bool

    public init(
        caip19: String,
        code: String,
        name: String? = nil,
        network: String,
        source: MoonPayAssetSource? = nil,
        contractAddress: String? = nil,
        decimals: Int? = nil,
        precision: Int? = nil,
        isAvailable: Bool = true
    ) {
        self.caip19 = caip19
        self.code = code
        self.name = name
        self.network = network
        self.source = source
        self.contractAddress = contractAddress
        self.decimals = decimals
        self.precision = precision
        self.isAvailable = isAvailable
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        caip19 = try container.decodeIfPresent(String.self, forKey: .caip19) ?? ""
        code = try container.decode(String.self, forKey: .code)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        network = try container.decodeIfPresent(String.self, forKey: .network) ?? ""
        source = try? container.decodeIfPresent(MoonPayAssetSource.self, forKey: .source)
        contractAddress = try container.decodeIfPresent(String.self, forKey: .contractAddress)
        decimals = try container.decodeIfPresent(Int.self, forKey: .decimals)
        precision = try container.decodeIfPresent(Int.self, forKey: .precision)
        let status = try container.decodeIfPresent(Status.self, forKey: .status)
        isAvailable = !(status?.suspended ?? false) && !(status?.disabled ?? false)
    }

    /// The reference a quote request takes for this asset.
    public var quoteReference: MoonPayAsset {
        source == .defi && !caip19.isEmpty ? MoonPayAsset(caip19: caip19) : MoonPayAsset(code: code)
    }

    private struct Status: Decodable {
        let suspended: Bool?
        let disabled: Bool?
    }

    private enum CodingKeys: String, CodingKey {
        case caip19, code, name, network, source, contractAddress, decimals, precision, status
    }
}

public struct MoonPayAssetsPage: Equatable, Sendable {
    public let assets: [MoonPayPlatformAsset]
    public let nextCursor: String?

    public init(assets: [MoonPayPlatformAsset], nextCursor: String?) {
        self.assets = assets
        self.nextCursor = nextCursor
    }
}

struct MoonPayAssetsResponse: Decodable {
    struct PageInfo: Decodable {
        let nextCursor: String?
    }

    let data: [MoonPayPlatformAsset]
    let pageInfo: PageInfo?
}

import TKLogging
import TonSwift
import TronSwift
import UIKit

public enum AssetIdResolver {
    public static func chartIdentifier(for assetId: String) -> String? {
        guard let components = AssetIdComponents(assetId: assetId) else {
            return nil
        }
        switch components {
        case let .coin(chain, _, _):
            let normalizedChain = chain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            switch normalizedChain {
            case "ton":
                return TonInfo.symbol
            case "tron":
                return TRX.symbol
            default:
                return nil
            }
        case let .asset(chain, _, _, address):
            let normalizedChain = chain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            switch normalizedChain {
            case "tron":
                return JettonMasterAddress.tonUSDT.toRaw()
            default:
                return address
            }
        }
    }
}

public enum AssetId {
    public static func coin(chain: MultichainChain, network: Network) -> String {
        "\(chain.rawValue)/\(network.assetIdNetworkIdentifier)/coin"
    }

    public static func jetton(address: TonSwift.Address, network: Network) -> String {
        asset(chain: .ton, type: "jetton", address: address.toRaw(), network: network)
    }

    public static func nft(address: TonSwift.Address, network: Network) -> String {
        asset(chain: .ton, type: "nft", address: address.toRaw(), network: network)
    }

    public static func trc20(address: String, network: Network) -> String {
        asset(chain: .tron, type: "trc20", address: address, network: network)
    }

    private static func asset(
        chain: MultichainChain,
        type: String,
        address: String,
        network: Network
    ) -> String {
        "\(chain.rawValue)/\(network.assetIdNetworkIdentifier)/\(type)/\(address)"
    }
}

private extension Network {
    var assetIdNetworkIdentifier: String {
        switch self {
        case .mainnet: "mainnet"
        case .testnet: "testnet"
        }
    }
}

public enum AssetIdComponents {
    case coin(chain: String, network: String, coin: String)
    case asset(chain: String, network: String, type: String, address: String)

    public init?(assetId: String) {
        let components = assetId.split(
            separator: "/",
            omittingEmptySubsequences: true
        ).map {
            String($0)
        }
        switch components.count {
        case 3:
            self = .coin(
                chain: components[0],
                network: components[1],
                coin: components[2]
            )
        case 4:
            self = .asset(
                chain: components[0],
                network: components[1],
                type: components[2],
                address: components[3]
            )
        default:
            Log.w(
                "invalid asset identifier",
                error: MultichainLoggingError.invalidAssetIdentifier(componentCount: components.count)
            )
            return nil
        }
    }

    public var chain: String {
        switch self {
        case let .coin(chain, _, _):
            chain
        case let .asset(chain, _, _, _):
            chain
        }
    }
}

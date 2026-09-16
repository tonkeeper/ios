@preconcurrency import AnyCodable
import Foundation

public struct WalletConnectWalletCapabilitiesRequest: Sendable, Equatable {
    public let address: String
    public let chainIds: [String]

    public init(
        address: String,
        chainIds: [String]
    ) {
        self.address = address
        self.chainIds = chainIds
    }

    var unsupportedAtomicResponse: WalletConnectResponseValue {
        var response = [String: Any]()
        for chainId in chainIds {
            response[chainId] = [
                "atomic": [
                    "status": "unsupported",
                ],
            ]
        }
        return .json(AnyCodable(response))
    }
}

struct WalletConnectWalletCapabilitiesScope: Sendable, Equatable {
    private let supportedChainIdsByAddress: [String: Set<String>]

    init(accounts: [Account]) {
        supportedChainIdsByAddress = accounts.reduce(into: [String: Set<String>]()) { result, account in
            guard let chainId = account.chainId.walletConnectCanonicalHexChainId else {
                return
            }
            result[account.address.lowercased(), default: []].insert(chainId)
        }
    }

    func unsupportedAtomicResponse(
        for request: WalletConnectWalletCapabilitiesRequest
    ) -> WalletConnectWalletCapabilitiesResolution {
        let authorizedChainIds = supportedChainIdsByAddress[request.address.lowercased()] ?? []
        guard !authorizedChainIds.isEmpty else {
            return .unauthorized
        }

        let supportedRequestChainIds = request.chainIds.filter { chainId in
            guard let canonicalChainId = chainId.walletConnectCanonicalHexChainId else {
                return false
            }
            return authorizedChainIds.contains(canonicalChainId)
        }
        let scopedRequest = WalletConnectWalletCapabilitiesRequest(
            address: request.address,
            chainIds: supportedRequestChainIds
        )
        return .response(scopedRequest.unsupportedAtomicResponse)
    }
}

extension WalletConnectWalletCapabilitiesScope {
    struct Account: Sendable, Equatable {
        let address: String
        let chainId: String
    }
}

enum WalletConnectWalletCapabilitiesResolution: Equatable {
    case response(WalletConnectResponseValue)
    case unauthorized
}

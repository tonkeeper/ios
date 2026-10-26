import Foundation
import KeeperCore
import TKLogging

enum EVMProviderRequest: Equatable {
    case accounts
    case chainId
    case netVersion
    case switchChain(chainId: String)
    case sendTransaction(WalletConnectEVMTransaction)
    case personalSign(message: String, address: String)
    case signTypedDataV4(address: String, typedData: String)
    case unsupported(method: String)

    init?(args: [Any]) {
        guard let payload = args.first, JSONSerialization.isValidJSONObject(payload) else {
            return nil
        }
        do {
            let data = try JSONSerialization.data(withJSONObject: payload)
            self = try JSONDecoder().decode(EVMProviderRequest.self, from: data)
        } catch {
            Log.w("earn evm request is malformed", extraInfo: ["error": "\(error)"])
            return nil
        }
    }
}

extension EVMProviderRequest: Decodable {
    private enum CodingKeys: String, CodingKey {
        case method
        case params
    }

    private struct SwitchChainParameter: Decodable {
        let chainId: String
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let method = try container.decode(String.self, forKey: .method)
        switch method {
        case "eth_accounts", "eth_requestAccounts":
            self = .accounts
        case "eth_chainId":
            self = .chainId
        case "net_version":
            self = .netVersion
        case WalletConnectMethod.walletSwitchEthereumChain.rawValue:
            self = try .switchChain(chainId: Self.firstParameter(SwitchChainParameter.self, in: container).chainId)
        case WalletConnectMethod.ethSendTransaction.rawValue:
            self = try .sendTransaction(Self.firstParameter(WalletConnectEVMTransaction.self, in: container))
        case WalletConnectMethod.personalSign.rawValue:
            let params = try Self.stringParameters(count: 2, in: container)
            self = .personalSign(message: params[0], address: params[1])
        case WalletConnectMethod.ethSignTypedDataV4.rawValue:
            let params = try Self.stringParameters(count: 2, in: container)
            self = .signTypedDataV4(address: params[0], typedData: params[1])
        case "":
            throw DecodingError.dataCorruptedError(forKey: .method, in: container, debugDescription: "method is empty")
        default:
            self = .unsupported(method: method)
        }
    }

    private static func firstParameter<Parameter: Decodable>(
        _: Parameter.Type,
        in container: KeyedDecodingContainer<CodingKeys>
    ) throws -> Parameter {
        guard let parameter = try container.decode([Parameter].self, forKey: .params).first else {
            throw DecodingError.dataCorruptedError(forKey: .params, in: container, debugDescription: "params are empty")
        }
        return parameter
    }

    private static func stringParameters(
        count: Int,
        in container: KeyedDecodingContainer<CodingKeys>
    ) throws -> [String] {
        let params = try container.decode([String].self, forKey: .params)
        guard params.count >= count else {
            throw DecodingError.dataCorruptedError(
                forKey: .params,
                in: container,
                debugDescription: "expected \(count) string params, got \(params.count)"
            )
        }
        return params
    }
}

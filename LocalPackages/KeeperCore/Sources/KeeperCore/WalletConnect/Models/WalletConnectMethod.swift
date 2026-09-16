import Foundation

public enum WalletConnectMethod: String, CaseIterable, Codable, Sendable, Equatable {
    case personalSign = "personal_sign"
    case ethSignTypedDataV4 = "eth_signTypedData_v4"
    case ethSignTransaction = "eth_signTransaction"
    case ethSendTransaction = "eth_sendTransaction"
    case walletSwitchEthereumChain = "wallet_switchEthereumChain"
    case walletGetCapabilities = "wallet_getCapabilities"
    case tronSignMessage = "tron_signMessage"
    case tronSignTransaction = "tron_signTransaction"
    case tonSendMessage = "ton_sendMessage"
    case tonSignData = "ton_signData"
}

extension WalletConnectMethod {
    static let evmMethods: Set<WalletConnectMethod> = [
        .personalSign,
        .ethSignTypedDataV4,
        .ethSignTransaction,
        .ethSendTransaction,
        .walletSwitchEthereumChain,
        .walletGetCapabilities,
    ]

    static let tronMethods: Set<WalletConnectMethod> = [
        .tronSignMessage,
        .tronSignTransaction,
    ]

    static let tonMethods: Set<WalletConnectMethod> = [
        .tonSendMessage,
        .tonSignData,
    ]

    static func supportedMethods(namespace: String) -> Set<WalletConnectMethod> {
        switch namespace.components(separatedBy: ":").first {
        case "eip155":
            return evmMethods
        case "tron":
            return tronMethods
        case "ton":
            return tonMethods
        default:
            return []
        }
    }

    static func supportedMethods(chain: WalletConnectChain) -> Set<WalletConnectMethod> {
        supportedMethods(namespace: chain.namespace)
    }

    func isSupported(chain: WalletConnectChain) -> Bool {
        Self.supportedMethods(chain: chain).contains(self)
    }
}

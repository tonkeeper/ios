import Foundation

@frozen public enum WalletConnectMethod: String, CaseIterable, Codable, Sendable, Equatable {
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
    case solanaGetAccounts = "solana_getAccounts"
    case solanaRequestAccounts = "solana_requestAccounts"
    case solanaSignMessage = "solana_signMessage"
    case solanaSignTransaction = "solana_signTransaction"
    case solanaSignAndSendTransaction = "solana_signAndSendTransaction"
    case solanaSignAllTransactions = "solana_signAllTransactions"
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

    static let solanaMethods: Set<WalletConnectMethod> = [
        .solanaGetAccounts,
        .solanaRequestAccounts,
        .solanaSignMessage,
        .solanaSignTransaction,
        .solanaSignAndSendTransaction,
        .solanaSignAllTransactions,
    ]

    static func supportedMethods(namespace: String) -> Set<WalletConnectMethod> {
        switch namespace.components(separatedBy: ":").first {
        case "eip155":
            return evmMethods
        case "tron":
            return tronMethods
        case "ton":
            return tonMethods
        case "solana":
            return solanaMethods
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

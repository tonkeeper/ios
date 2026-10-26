import Foundation

@frozen public enum WalletConnectRequestPayload: Sendable, Equatable {
    case signMessage(WalletConnectSignMessage)
    case evmTransaction(WalletConnectEVMTransaction, send: Bool)
    case switchEthereumChain(WalletConnectChain)
    case walletCapabilities(WalletConnectWalletCapabilitiesRequest)
    case tronTransaction(WalletConnectTronTransaction)
    case tonSendMessage(WalletConnectTONSendMessage)
    case tonSignData(WalletConnectTONSignData)
    case solanaAccounts
    case solanaTransaction(WalletConnectSolanaTransaction, send: Bool)
    case solanaTransactionBatch(WalletConnectSolanaTransactionBatch)
}

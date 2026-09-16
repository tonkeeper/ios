@preconcurrency import ReownWalletKit

extension JSONRPCError {
    static let walletConnectUserRejected = JSONRPCError(
        code: 5000,
        message: "User rejected."
    )

    static let walletConnectInvalidParams = JSONRPCError.invalidParams

    static let walletConnectUnsupportedChain = JSONRPCError(
        code: 4902,
        message: "Unrecognized chain ID."
    )

    static let walletConnectUnauthorized = JSONRPCError(
        code: 4100,
        message: "Unauthorized"
    )

    static let walletConnectAtomicityNotSupported = JSONRPCError(
        code: 5760,
        message: "Atomicity not supported"
    )

    static let walletConnectNotImplemented = JSONRPCError(
        code: -32603,
        message: "Not implemented."
    )
}

import TKLogging

public extension LogDomain {
    static var walletConnect: LogDomain {
        LogDomain(category: "WalletConnect")
    }
}

public extension Log {
    static var walletConnect: LogDomain {
        .walletConnect
    }
}

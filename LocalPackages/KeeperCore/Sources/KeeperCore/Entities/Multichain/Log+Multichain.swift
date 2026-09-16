import TKLogging

public extension LogDomain {
    static var multichain: LogDomain {
        LogDomain(category: "Multichain")
    }
}

public extension Log {
    static var multichain: LogDomain {
        .multichain
    }
}

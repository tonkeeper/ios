import TKLogging

public extension LogDomain {
    static var chainKit: LogDomain {
        LogDomain(category: "ChainKit")
    }
}

public extension Log {
    static var chainKit: LogDomain {
        .chainKit
    }
}

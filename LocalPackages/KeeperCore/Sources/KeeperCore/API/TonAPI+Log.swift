import TKLogging

public extension LogDomain {
    static var tonAPI: LogDomain {
        LogDomain(category: "TonAPI")
    }
}

public extension Log {
    static var tonAPI: LogDomain {
        .tonAPI
    }
}

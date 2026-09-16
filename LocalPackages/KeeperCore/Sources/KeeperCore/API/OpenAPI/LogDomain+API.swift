import TKLogging

public extension LogDomain {
    static var api: LogDomain {
        LogDomain(category: "API")
    }
}

public extension Log {
    static var api: LogDomain {
        .api
    }
}

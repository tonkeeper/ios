import TKLogging

public extension LogDomain {
    static var tron: LogDomain {
        LogDomain(category: "Tron")
    }
}

public extension Log {
    static var tron: LogDomain {
        .tron
    }
}

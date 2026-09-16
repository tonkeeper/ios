import TKLogging

public extension LogDomain {
    static var multichainSwap: LogDomain {
        LogDomain(category: "MultichainSwap")
    }
}

public extension Log {
    static var multichainSwap: LogDomain {
        .multichainSwap
    }
}

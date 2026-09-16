import TKLogging

public extension LogDomain {
    static var multichainRamp: LogDomain {
        LogDomain(category: "MultichainRamp")
    }
}

public extension Log {
    static var multichainRamp: LogDomain {
        .multichainRamp
    }
}

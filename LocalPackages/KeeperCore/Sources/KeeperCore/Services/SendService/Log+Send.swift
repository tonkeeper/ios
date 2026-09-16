import TKLogging

public extension LogDomain {
    static var send: LogDomain {
        LogDomain(category: "Send")
    }
}

public extension Log {
    static var send: LogDomain {
        .send
    }
}

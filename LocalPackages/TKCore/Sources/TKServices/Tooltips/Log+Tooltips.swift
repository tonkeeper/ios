import TKLogging

extension LogDomain {
    static var tooltips: LogDomain {
        LogDomain(category: "Tooltips")
    }
}

extension Log {
    static var tooltips: LogDomain {
        .tooltips
    }
}

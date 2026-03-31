import Foundation

public struct LogRecord: Sendable {
    public let timestamp: Date
    public let subsystem: String
    public let category: String
    public let severity: LogSeverity
    public let message: String
    public let file: String
    public let function: String
    public let line: UInt
    public let extraInfo: [String: String]

    public init(
        timestamp: Date,
        subsystem: String,
        category: String,
        severity: LogSeverity,
        message: String,
        file: String,
        function: String,
        line: UInt,
        extraInfo: [String: String] = [:]
    ) {
        self.timestamp = timestamp
        self.subsystem = subsystem
        self.category = category
        self.severity = severity
        self.message = message
        self.file = file
        self.function = function
        self.line = line
        self.extraInfo = extraInfo
    }
}

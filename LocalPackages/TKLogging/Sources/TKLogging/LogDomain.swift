import Foundation
import OSLog

public struct LogDomain: Sendable {
    public let subsystem: String?
    public let category: String
    public let prefix: String?

    public init(subsystem: String? = nil, category: String = "default", prefix: String? = nil) {
        self.subsystem = subsystem
        self.category = category
        self.prefix = prefix
    }

    public func log(
        _ severity: LogSeverity,
        _ message: @autoclosure () -> String,
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line,
        error: (any Error)? = nil,
        extraInfo: [String: String] = [:]
    ) {
        let configuration = Log.configuration
        guard severity >= configuration.minimumSeverity, !configuration.backends.isEmpty else {
            return
        }

        var extraInfo = extraInfo
        if let error {
            extraInfo["error"] = error.logDescription
        }

        let text = message()
        let record = LogRecord(
            timestamp: Date(),
            subsystem: subsystem ?? configuration.defaultSubsystem,
            category: category,
            severity: severity,
            message: prefix.map { "\($0) \(text)" } ?? text,
            file: String(describing: file),
            function: String(describing: function),
            line: line,
            extraInfo: extraInfo
        )

        configuration.backends.forEach { $0.log(record) }
    }

    public func d(
        _ message: @autoclosure () -> String,
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line,
        error: (any Error)? = nil,
        extraInfo: [String: String] = [:]
    ) {
        log(.debug, message(), file: file, function: function, line: line, error: error, extraInfo: extraInfo)
    }

    public func i(
        _ message: @autoclosure () -> String,
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line,
        error: (any Error)? = nil,
        extraInfo: [String: String] = [:]
    ) {
        log(.info, message(), file: file, function: function, line: line, error: error, extraInfo: extraInfo)
    }

    public func w(
        _ message: @autoclosure () -> String,
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line,
        error: (any Error)? = nil,
        extraInfo: [String: String] = [:]
    ) {
        log(.warning, message(), file: file, function: function, line: line, error: error, extraInfo: extraInfo)
    }

    public func e(
        _ message: @autoclosure () -> String,
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line,
        error: (any Error)? = nil,
        extraInfo: [String: String] = [:]
    ) {
        log(.error, message(), file: file, function: function, line: line, error: error, extraInfo: extraInfo)
    }
}

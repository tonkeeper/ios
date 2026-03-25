import Foundation
import OSLog

public struct LogDomain: Sendable {
    public let subsystem: String?
    public let category: String

    public init(subsystem: String? = nil, category: String = "default") {
        self.subsystem = subsystem
        self.category = category
    }

    public func log(
        _ severity: LogSeverity,
        _ message: @autoclosure () -> String,
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line,
        extraInfo: [String: String] = [:]
    ) {
        let configuration = Log.configuration

        guard severity >= configuration.minimumSeverity else {
            return
        }

        let record = LogRecord(
            timestamp: Date(),
            subsystem: subsystem ?? configuration.defaultSubsystem,
            category: category,
            severity: severity,
            message: message(),
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
        extraInfo: [String: String] = [:]
    ) {
        log(.debug, message(), file: file, function: function, line: line, extraInfo: extraInfo)
    }

    public func i(
        _ message: @autoclosure () -> String,
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line,
        extraInfo: [String: String] = [:]
    ) {
        log(.info, message(), file: file, function: function, line: line, extraInfo: extraInfo)
    }

    public func w(
        _ message: @autoclosure () -> String,
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line,
        extraInfo: [String: String] = [:]
    ) {
        log(.warning, message(), file: file, function: function, line: line, extraInfo: extraInfo)
    }

    public func e(
        _ message: @autoclosure () -> String,
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line,
        extraInfo: [String: String] = [:]
    ) {
        log(.error, message(), file: file, function: function, line: line, extraInfo: extraInfo)
    }
}

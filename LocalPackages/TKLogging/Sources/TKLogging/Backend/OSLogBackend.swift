import Foundation
import os

public final class OSLogBackend: LogBackend {
    private struct LoggerKey: Hashable {
        let subsystem: String
        let category: String
    }

    public let identifier: String

    private var loggers: [LoggerKey: Logger] = [:]
    private let lock = NSLock()

    public init(identifier: String = "oslog") {
        self.identifier = identifier
    }

    public func log(_ record: LogRecord) {
        let logger = logger(for: record)
        let message = Self.message(for: record)

        switch record.severity {
        case .debug:
            logger.debug("\(message, privacy: .public)")
        case .info:
            logger.info("\(message, privacy: .public)")
        case .warning:
            logger.error("\(message, privacy: .public)")
        case .error:
            logger.fault("\(message, privacy: .public)")
        }
    }

    /// The call site travels with warnings and errors only — those are the lines someone goes looking for.
    private static func message(for record: LogRecord) -> String {
        var message = record.message
        if !record.extraInfo.isEmpty {
            let info = record.extraInfo
                .sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: ", ")
            message += " {\(info)}"
        }
        guard record.severity >= .warning else {
            return message
        }
        return "\(message) at \(record.file):\(record.line)"
    }

    private func logger(for record: LogRecord) -> Logger {
        let key = LoggerKey(subsystem: record.subsystem, category: record.category)
        return lock.withLock {
            if let logger = loggers[key] {
                return logger
            }

            let logger = Logger(subsystem: record.subsystem, category: record.category)
            loggers[key] = logger
            return logger
        }
    }
}

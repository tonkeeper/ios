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

        switch record.severity {
        case .debug:
            logger.debug("\(record.message, privacy: .public)")
        case .info:
            logger.info("\(record.message, privacy: .public)")
        case .warning:
            logger.error("\(record.message, privacy: .public)")
        case .error:
            logger.fault("\(record.message, privacy: .public)")
        }
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

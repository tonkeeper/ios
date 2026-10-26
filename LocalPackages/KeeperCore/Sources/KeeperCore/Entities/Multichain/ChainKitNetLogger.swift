import ChainKit
import Foundation
import TKLogging

/// Sink for ChainKit's http log. Without one it goes to the platform default, which only reaches
/// the Xcode console — the same requests are then missing from the log file a user exports.
/// `NetConfig.isLogging` remains the switch for whether ChainKit emits anything at all.
final class ChainKitNetLogger: NSObject, ModuleNetLogger, @unchecked Sendable {
    private let domain: LogDomain

    init(domain: LogDomain = .chainKit) {
        self.domain = domain
    }

    /// `details` carries ChainKit's redacted RPC fields; they stay searchable in an exported log.
    func log(message: String, details: [String: String], level: ModuleLoggerLevel) {
        domain.log(Self.severity(of: level), message, extraInfo: details)
    }

    private static func severity(of level: ModuleLoggerLevel) -> LogSeverity {
        switch level {
        case .debug: .debug
        case .warning: .warning
        case .error: .error
        default: .info
        }
    }
}

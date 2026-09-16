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

    func log(message: String) {
        domain.i(message)
    }
}

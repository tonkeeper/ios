import Foundation

public struct LoggingConfiguration {
    public var minimumSeverity: LogSeverity
    public var defaultSubsystem: String
    public var backends: [any LogBackend]

    public init(
        minimumSeverity: LogSeverity = .error,
        defaultSubsystem: String = Bundle.main.bundleIdentifier ?? "com.tonkeeper",
        backends: [any LogBackend] = []
    ) {
        self.minimumSeverity = minimumSeverity
        self.defaultSubsystem = defaultSubsystem
        self.backends = backends
    }
}

extension LoggingConfiguration {
    static var `default`: LoggingConfiguration {
        LoggingConfiguration()
    }
}

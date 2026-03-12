import Foundation
import TKLogging

public final class CrashlyticsLogBackend: LogBackend {
    public let identifier: String

    private let reporter: CrashlyticsReporting
    private let minimumCrashlyticsSeverity: LogSeverity

    public init(
        identifier: String = "crashlytics",
        reporter: CrashlyticsReporting,
        minimumCrashlyticsSeverity: LogSeverity = .error
    ) {
        self.identifier = identifier
        self.reporter = reporter
        self.minimumCrashlyticsSeverity = minimumCrashlyticsSeverity
    }

    public func log(_ record: LogRecord) {
        guard record.severity >= minimumCrashlyticsSeverity else {
            return
        }
        reporter.recordNonFatal(
            message: record.message,
            domain: record.category,
            metadata: [
                "subsystem": record.subsystem,
                "file": record.file,
                "function": record.function,
                "line": String(record.line),
            ].reduce(into: record.extraInfo) { dict, element in
                dict[element.key] = element.value
            }
        )
    }
}

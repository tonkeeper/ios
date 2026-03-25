import TKCore
import TKFeatureFlags
import TKLogging
import UIKit

public extension Log {
    static func configure() {
        LogConfigurator(
            application: UIApplication.shared
        ).configure()
    }
}

private struct LogConfigurator {
    private let application: UIApplication

    init(application: UIApplication) {
        self.application = application
    }

    func configure() {
        let overridenSeverity = TKAppPreferences
            .minimumLogSeverityRawValue
            .flatMap(LogSeverity.init(rawValue:))
        let resolvedSeverity = overridenSeverity ?? defaultSeverity

        Log.configuration = if application.isAppStoreEnvironment {
            appStoreConfiguration(severity: resolvedSeverity)
        } else if application.isDebug {
            debugConfiguration(severity: resolvedSeverity)
        } else {
            defaultConfiguration(severity: resolvedSeverity)
        }
    }
}

extension LogConfigurator {
    private func appStoreConfiguration(
        severity: LogSeverity
    ) -> LoggingConfiguration {
        defaultConfiguration(severity: severity)
    }

    private func defaultConfiguration(
        severity: LogSeverity
    ) -> LoggingConfiguration {
        LoggingConfiguration(
            minimumSeverity: severity,
            backends: [
                CrashlyticsLogBackend(
                    reporter: CrashlyticsReporter(),
                    minimumCrashlyticsSeverity: .error
                ),
                OSLogBackend(),
            ]
        )
    }

    private func debugConfiguration(
        severity: LogSeverity
    ) -> LoggingConfiguration {
        LoggingConfiguration(
            minimumSeverity: severity,
            backends: [
                OSLogBackend(),
            ]
        )
    }

    private var defaultSeverity: LogSeverity {
        if application.isDebug {
            .debug
        } else {
            .info
        }
    }
}

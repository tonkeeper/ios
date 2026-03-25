import FirebaseCrashlytics
import Foundation

public protocol CrashlyticsReporting {
    func recordNonFatal(message: String, domain: String, metadata: [String: String])
}

public final class CrashlyticsReporter: CrashlyticsReporting {
    public init() {}

    public func recordNonFatal(message: String, domain: String, metadata: [String: String] = [:]) {
        var userInfo: [String: Any] = ["message": message]
        for (key, value) in metadata {
            userInfo[key] = value
        }
        let error = NSError(domain: domain, code: 0, userInfo: userInfo)
        Crashlytics.crashlytics().record(error: error)
    }
}

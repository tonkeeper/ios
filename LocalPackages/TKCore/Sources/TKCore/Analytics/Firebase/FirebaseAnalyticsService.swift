import FirebaseAnalytics
import Foundation

final class FirebaseAnalyticsService: AnalyticsService {
    init() {}

    func logEvent(name: String, args: [String: Any]) {
        Analytics.logEvent(name, parameters: args)
    }
}

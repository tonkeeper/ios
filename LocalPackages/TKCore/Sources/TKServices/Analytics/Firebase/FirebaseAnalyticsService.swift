import FirebaseAnalytics
import Foundation

package final class FirebaseAnalyticsService: AnalyticsService {
    package init() {}

    package func logEvent(name: String, args: [String: Any]) {
        Analytics.logEvent(name, parameters: args)
    }
}

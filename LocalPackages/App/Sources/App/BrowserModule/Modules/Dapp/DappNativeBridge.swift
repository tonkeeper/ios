import Foundation
import TKCore
import TKUIKit

enum DappNativeBridge {
    enum ErrorCode: Int {
        case unsupportedMethod = 1
        case invalidParams = 2
    }

    enum ErrorMessage {
        static let unsupportedMethod = "Unsupported method"
        static let missingEvent = "Missing event"
    }

    struct Config {
        let theme: String
        let locale: String
        let featuredVaults: [String]

        static func current() -> Config {
            Config(
                theme: TKThemeManager.shared.theme.stringDescription,
                locale: Locale.preferredLanguages.first ?? "en",
                featuredVaults: []
            )
        }

        var json: String {
            let dictionary: [String: Any] = [
                "theme": theme,
                "locale": locale,
                "featuredVaults": featuredVaults,
            ]
            guard let data = try? JSONSerialization.data(withJSONObject: dictionary, options: [.sortedKeys]),
                  let string = String(data: data, encoding: .utf8)
            else {
                return "{}"
            }
            return string
        }
    }

    static func injection(config: Config) -> String {
        """
        if (!window.native) {
            window.native = {
                config: \(config.json),
                invoke: (method, params) => new Promise((resolve, reject) => window.invokeRnFunc(method, [params || {}], resolve, reject)),
                on: () => () => {},
            };
        }
        """
    }

    static func trackParams(_ params: [String: Any]?) -> [String: Any] {
        guard let params else { return [:] }
        return params.filter { key, value in
            AnalyticsLimits.isValidPropertyKey(key) && (value is String || value is NSNumber)
        }
    }
}

import Foundation
import KeeperCore
import TKCore
import TKLogging
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

    enum Event: String {
        case themeChanged = "config.themeChanged"
    }

    struct Config {
        let theme: String
        let locale: String
        let featuredVaults: [EarnFeaturedVault]

        static func current(featuredVaults: [EarnFeaturedVault]) -> Config {
            Config(
                theme: DappNativeBridge.theme,
                locale: Bundle.main.preferredLocalizations.first ?? "en",
                featuredVaults: featuredVaults
            )
        }

        var json: String {
            let dictionary: [String: Any] = [
                "theme": theme,
                "locale": locale,
                "featuredVaults": featuredVaults.map(\.bridgeJson),
            ]
            guard let data = try? JSONSerialization.data(withJSONObject: dictionary, options: [.sortedKeys]),
                  let string = String(data: data, encoding: .utf8)
            else {
                return "{}"
            }
            return string
        }
    }

    static var theme: String {
        TKThemeManager.shared.theme.stringDescription
    }

    static func injection(config: Config) -> String {
        """
        if (!window.native) {
            window.nativeEventListeners = {};
            window.addEventListener('message', ({ data }) => {
                if (!data || data.type !== '\(DappBridgeMessageType.nativeEvent.rawValue)' || !window.native) {
                    return;
                }
                if (data.event === '\(Event.themeChanged.rawValue)' && data.payload) {
                    window.native.config = Object.assign({}, window.native.config, { theme: data.payload.theme });
                }
                const listeners = window.nativeEventListeners[data.event];
                if (!listeners) {
                    return;
                }
                listeners.slice().forEach((handler) => handler(data.payload));
            });
            window.native = {
                config: \(config.json),
                invoke: (method, params) => new Promise((resolve, reject) => window.invokeRnFunc(method, [params || {}], resolve, reject)),
                on: (event, handler) => {
                    const listeners = window.nativeEventListeners[event] || (window.nativeEventListeners[event] = []);
                    listeners.push(handler);
                    return () => {
                        const index = listeners.indexOf(handler);
                        if (index > -1) {
                            listeners.splice(index, 1);
                        }
                    };
                },
            };
        }
        """
    }

    struct ThemePayload: Encodable {
        let theme: String
    }

    static func eventJson(name: String, payload: some Encodable) -> String? {
        let envelope = NativeEventEnvelope(
            type: DappBridgeMessageType.nativeEvent.rawValue,
            event: name,
            payload: payload
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        do {
            return try String(data: encoder.encode(envelope), encoding: .utf8)
        } catch {
            Log.w("native event is not encodable", extraInfo: ["event": name, "error": "\(error)"])
            return nil
        }
    }

    static func trackParams(_ params: [String: Any]?) -> [String: Any] {
        guard let params else { return [:] }
        return params.filter { key, value in
            AnalyticsLimits.isValidPropertyKey(key) && (value is String || value is NSNumber)
        }
    }
}

private extension EarnFeaturedVault {
    var bridgeJson: [String: String] {
        [
            "network": network,
            "vaultId": vaultId,
        ]
    }
}

private struct NativeEventEnvelope<Payload: Encodable>: Encodable {
    let type: String
    let event: String
    let payload: Payload
}

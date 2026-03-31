import Aptabase
import Foundation

public enum EventKey: String {
    case clickDapp = "click_dapp"
    case launchApp = "launch_app"
    case importWallet = "import_wallet"
    case importWatchOnly = "import_watch_only"
    case generateWallet = "generate_wallet"
    case deleteWallet = "delete_wallet"
    case resetWallet = "reset_wallet"
    case openBrowser = "browser_open"
    case dappSharingCopy = "dapp_sharing_copy"

    case storyOpen = "story_open"
    case storyPageView = "story_page_view"
    case storyClick = "story_click"

    case pushClick = "push_click"

    case onrampOpen = "onramp_open"
    case onrampClick = "onramp_click"

    public var parameters: [String: Any] {
        [:]
    }

    public var key: String {
        rawValue
    }
}

public struct AnalyticsEventLegacy {
    public let name: String
    public let params: [String: Any]
}

public protocol AnalyticsService {
    func logEvent(name: String, args: [String: Any])
}

public struct AnalyticsProvider {
    private let services: [AnalyticsService]
    private let uniqueIdProvider: UniqueIdProvider

    public init(
        analyticsServices: [AnalyticsService],
        uniqueIdProvider: UniqueIdProvider
    ) {
        self.services = analyticsServices
        self.uniqueIdProvider = uniqueIdProvider
    }

    public func log(_ event: Codable) {
        guard var dict = event.asDictionary() else {
            return
        }

        guard let name = dict.removeValue(forKey: "eventName") as? String else {
            return
        }

        self.log(name: name, args: dict)
    }

    public func log(eventKey: EventKey, args: [String: Any] = [:]) {
        self.log(name: eventKey.key, args: args)
    }

    public func log(event: AnalyticsEventLegacy) {
        self.log(name: event.name, args: event.params)
    }

    private func log(name: String, args: [String: Any] = [:]) {
        let baseEvent = AnalyticsEventMobileNative(
            firebaseUserId: uniqueIdProvider.uniqueDeviceId.uuidString,
            platform: .iosNative
        )
        log(name: name, args: args, baseEvent: baseEvent)
    }

    private func log(
        name: String,
        args: [String: Any],
        baseEvent: AnalyticsEventMobileNative
    ) {
        let baseParameters = baseEvent.asDictionary() ?? [:]
        let allParameters = args.reduce(into: baseParameters) { result, element in
            result[element.key] = element.value
        }
        for service in services {
            service.logEvent(name: name, args: allParameters)
        }
    }

    public enum ClickDappEventFrom: String {
        case banner
        case browser
        case browserConnected = "browser_connected"
    }

    public func logClickDappEvent(
        name: String,
        url: String,
        from: ClickDappEventFrom
    ) {
        log(
            eventKey: .clickDapp,
            args: [
                "name": name,
                "url": url,
                "from": from.rawValue,
            ]
        )
    }
}

// MARK: - Native Swap Events

public extension AnalyticsEventLegacy {
    enum NativeSwap {
        public static func open() -> AnalyticsEventLegacy {
            .init(name: "swap_open", params: ["type": "native"])
        }

        public static func click(from: String, to: String) -> AnalyticsEventLegacy {
            .init(name: "swap_click", params: [
                "jetton_symbol_from": from,
                "jetton_symbol_to": to,
                "type": "native",
            ])
        }

        public static func confirm(from: String, to: String, feeProvider: String) -> AnalyticsEventLegacy {
            .init(name: "swap_confirm", params: [
                "fee_paid_in": feeProvider,
                "jetton_symbol_from": from,
                "jetton_symbol_to": to,
                "provider_name": "ston.fi",
                "type": "native",
            ])
        }

        public static func failed(from: String, to: String, feeProvider: String, error: Error) -> AnalyticsEventLegacy {
            .init(name: "swap_failed", params: [
                "error_message": error.localizedDescription,
                "fee_paid_in": feeProvider,
                "jetton_symbol_from": from,
                "jetton_symbol_to": to,
                "provider_name": "ston.fi",
                "type": "native",
            ])
        }

        public static func success(from: String, to: String, feeProvider: String) -> AnalyticsEventLegacy {
            .init(name: "swap_success", params: [
                "fee_paid_in": feeProvider,
                "jetton_symbol_from": from,
                "jetton_symbol_to": to,
                "provider_name": "ston.fi",
                "type": "native",
            ])
        }
    }
}

private extension Encodable {
    func asDictionary() -> [String: Any]? {
        do {
            let data = try JSONEncoder().encode(self)
            let jsonObject = try JSONSerialization.jsonObject(
                with: data,
                options: .allowFragments
            )
            guard let dict = jsonObject as? [String: Any] else {
                return nil
            }
            return dict
        } catch {
            return nil
        }
    }
}

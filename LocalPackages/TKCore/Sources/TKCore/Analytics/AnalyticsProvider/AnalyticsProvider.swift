import Aptabase
import Foundation
import KeeperCore

public enum EventKey: String, CaseIterable {
    case deleteWallet = "delete_wallet"
    case resetWallet = "reset_wallet"
    case sensitiveContentScreenshot = "sensitive_content_screenshot"

    case storyOpen = "story_open"
    case storyPageView = "story_page_view"
    case storyClick = "story_click"

    case onrampOpen = "onramp_open"
    case onrampClick = "onramp_click"

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
    private let firebaseService: FirebaseAnalyticsService
    private let uniqueIdProvider: UniqueIdProvider
    private let deviceIdProvider: () -> String?
    private let appInfoProvider: AppInfoProvider
    private let keysCountryCodeProvider: KeysCountryCodeProvider

    public init(
        analyticsServices: [AnalyticsService],
        uniqueIdProvider: UniqueIdProvider,
        deviceIdProvider: @escaping () -> String? = { nil },
        appInfoProvider: AppInfoProvider,
        keysCountryCodeProvider: KeysCountryCodeProvider
    ) {
        self.services = analyticsServices
        self.firebaseService = FirebaseAnalyticsService()
        self.uniqueIdProvider = uniqueIdProvider
        self.deviceIdProvider = deviceIdProvider
        self.appInfoProvider = appInfoProvider
        self.keysCountryCodeProvider = keysCountryCodeProvider
    }

    /// `utm` tags the event with the campaign of the link that opened the flow it belongs to. Only the
    /// events of that flow carry it: attribution beyond them is decided on the analytics side.
    public func log(_ event: Encodable, utm: UtmParameters = .empty) {
        guard var dict = event.asDictionary() else {
            return
        }

        guard let name = dict.removeValue(forKey: "eventName") as? String else {
            return
        }

        self.log(name: name, args: dict, utm: utm)
    }

    public func log(eventKey: EventKey, args: [String: Any] = [:], utm: UtmParameters = .empty) {
        self.log(name: eventKey.key, args: args, utm: utm)
    }

    public func log(event: AnalyticsEventLegacy, utm: UtmParameters = .empty) {
        self.log(name: event.name, args: event.params, utm: utm)
    }

    private func log(
        name: String,
        args: [String: Any] = [:],
        utm: UtmParameters
    ) {
        let baseEvent = AnalyticsEventMobileNative(
            firebaseUserId: uniqueIdProvider.uniqueDeviceId.uuidString,
            deviceId: deviceIdProvider(),
            platform: .iosNative,
            storeCountryCode: appInfoProvider.cachedStoreCountryCode?.uppercased(),
            deviceCountryCode: appInfoProvider.deviceCountryCode?.uppercased(),
            keysCountryCode: keysCountryCodeProvider.keysCountryCode,
            utmSource: utm.source,
            utmMedium: utm.medium,
            utmCampaign: utm.campaign,
            utmTerm: utm.term,
            utmContent: utm.content
        )
        log(name: name, args: args, baseEvent: baseEvent)
    }

    private func log(
        name: String,
        args: [String: Any],
        baseEvent: AnalyticsEventMobileNative
    ) {
        let baseParameters = baseEvent.asDictionary() ?? [:]
        let allParameters = AnalyticsLimits.sanitizeKeys(
            args.reduce(into: baseParameters) { result, element in
                result[element.key] = element.value
            }
        )
        for service in services {
            service.logEvent(name: name, args: allParameters)
        }
    }

    public func logSwapCompleted() {
        logFirebase(name: "swap_completed")
    }

    public func logStakeCompleted() {
        logFirebase(name: "stake_completed")
    }

    public func logSeedBackupConfirmed() {
        logFirebase(name: "seed_backup_confirmed")
    }

    public func logBatteryCharged() {
        logFirebase(name: "battery_charged")
    }

    public func logDepositCompleted() {
        logFirebase(name: "deposit_completed")
    }

    private func logFirebase(name: String) {
        firebaseService.logEvent(name: name, args: [:])
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

// MARK: - Dapp Bridge Events

public extension AnalyticsEventLegacy {
    enum Dapp {
        public static func track(event: String, params: [String: Any]) -> AnalyticsEventLegacy {
            .init(name: event, params: params)
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

import Foundation
import KeeperCore
import TKCore
import TKLogging
import TKUIKit
import UIKit

enum KeeperDappBridge {
    static let messageHandlerName = "browserMessages"
    static let loyaltyURL = URL(string: "https://loyalty.keeperwallet.com/")!

    static func loyaltyURL(referralCode: String?) -> URL {
        guard let referralCode,
              var components = URLComponents(url: loyaltyURL.appendingPathComponent("referrals"), resolvingAgainstBaseURL: false)
        else {
            return loyaltyURL
        }
        components.queryItems = [URLQueryItem(name: "referralCode", value: referralCode)]
        return components.url ?? loyaltyURL
    }

    enum Method: Equatable {
        case getData
        case refreshData(expiredAccessToken: String)
        case close
        case haptic(HapticStyle)
        case setCloseButton(isVisible: Bool)
        case share(text: String)
        case track(event: String, params: NSDictionary)

        var name: String {
            switch self {
            case .getData: "get-data"
            case .refreshData: "refresh-data"
            case .close: "close"
            case .haptic: "haptic"
            case .setCloseButton: "set-close-button"
            case .share: "share"
            case .track: "analytics.track"
            }
        }
    }

    enum HapticStyle: String {
        case selection
        case light
        case medium
        case heavy
        case success
        case warning
        case error

        @MainActor
        func play() {
            switch self {
            case .selection: UISelectionFeedbackGenerator().selectionChanged()
            case .light: UIImpactFeedbackGenerator(style: .light).impactOccurred()
            case .medium: UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            case .heavy: UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            case .success: UINotificationFeedbackGenerator().notificationOccurred(.success)
            case .warning: UINotificationFeedbackGenerator().notificationOccurred(.warning)
            case .error: UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }

    enum ErrorCode: String, Error {
        case unauthorized = "UNAUTHORIZED"
        case unsupportedMethod = "UNSUPPORTED_METHOD"
        case invalidParams = "INVALID_PARAMS"
        case forbidden = "FORBIDDEN"
        case internalError = "INTERNAL_ERROR"

        var message: String {
            switch self {
            case .unauthorized: "Authorization failed"
            case .unsupportedMethod: "Unsupported method"
            case .invalidParams: "Invalid params"
            case .forbidden: "Forbidden"
            case .internalError: "Internal error"
            }
        }
    }

    struct Request: Equatable {
        let queryId: String
        let method: Result<Method, ErrorCode>
    }

    static func isTrusted(url: URL?) -> Bool {
        guard let url,
              url.scheme?.lowercased() == "https",
              (url.port ?? 443) == 443,
              let host = url.host?.lowercased()
        else {
            return false
        }
        return host.hasSuffix(".keeperwallet.com")
    }

    static func isLoyalty(url: URL) -> Bool {
        isTrusted(url: url) && url.host?.lowercased() == loyaltyURL.host
    }

    static func opensInSheet(url: URL) -> Bool {
        isTrusted(url: url) && !isLoyalty(url: url)
    }

    static func opensInSeparateDapp(newWindowURL: URL, from dappURL: URL) -> Bool {
        guard let scheme = newWindowURL.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
            return false
        }
        return isTrusted(url: dappURL) && !isTrusted(url: newWindowURL)
    }

    static func parse(_ body: Any) -> Request? {
        guard let envelope = body as? [String: Any],
              envelope["type"] as? String == "bridge-message"
        else {
            return ignored("expected bridge-message")
        }
        guard let queryId = envelope["queryId"] as? String, !queryId.isEmpty else {
            return ignored("missing or invalid queryId")
        }
        return Request(queryId: queryId, method: method(payload: envelope["payload"]))
    }

    static func getDataPayload(
        authorization: BatteryWebAuthorization,
        theme: String,
        language: String,
        referralCode: String?
    ) -> [String: String] {
        refreshDataPayload(authorization: authorization).merging(
            ["theme": theme, "language": language, "referralCode": referralCode].compactMapValues { $0 },
            uniquingKeysWith: { current, _ in current }
        )
    }

    static func theme(for theme: TKTheme) -> String {
        theme == .system ? theme.stringDescription : theme.rawValue
    }

    static func refreshDataPayload(authorization: BatteryWebAuthorization) -> [String: String] {
        [
            "walletId": authorization.walletId,
            "deviceToken": authorization.deviceToken,
            "walletToken": authorization.walletToken,
        ]
    }

    static func response(queryId: String, result: Result<[String: String], ErrorCode>) -> String? {
        let response: [String: Any] = switch result {
        case let .success(payload):
            ["queryId": queryId, "payload": payload, "error": NSNull()]
        case let .failure(code):
            ["queryId": queryId, "payload": NSNull(), "error": ["code": code.rawValue, "message": code.message]]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: response) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    static func script(response: String) -> String {
        """
        (function() {
            window.dispatchEvent(new MessageEvent('message', {
                data: \(response)
            }));
        })();
        """
    }

    static func endsSession(of wallet: Wallet, on event: WalletsStore.Event) -> Bool {
        switch event {
        case let .didChangeActiveWallet(_, activeWallet):
            activeWallet.id != wallet.id
        case let .didDeleteWallet(deletedWallet):
            deletedWallet.id == wallet.id
        case .didDeleteAll:
            true
        default:
            false
        }
    }

    private static func method(payload: Any?) -> Result<Method, ErrorCode> {
        guard let payload = payload as? String,
              let json = (try? JSONSerialization.jsonObject(with: Data(payload.utf8))) as? [String: Any],
              let type = json["type"] as? String
        else {
            return .failure(.invalidParams)
        }

        switch type {
        case "get-data":
            return .success(.getData)
        case "refresh-data":
            guard let accessToken = json["accessToken"] as? String, !accessToken.isEmpty else {
                return .failure(.invalidParams)
            }
            return .success(.refreshData(expiredAccessToken: accessToken))
        case "close":
            return .success(.close)
        case "haptic":
            guard let style = (json["style"] as? String).flatMap(HapticStyle.init(rawValue:)) else {
                return .failure(.invalidParams)
            }
            return .success(.haptic(style))
        case "set-close-button":
            guard let visible = json["visible"] as? NSNumber, CFGetTypeID(visible) == CFBooleanGetTypeID() else {
                return .failure(.invalidParams)
            }
            return .success(.setCloseButton(isVisible: visible.boolValue))
        case "share":
            guard let text = json["text"] as? String, text.contains(where: { !$0.isWhitespace }) else {
                return .failure(.invalidParams)
            }
            return .success(.share(text: text))
        case "analytics.track":
            guard let event = json["event"] as? String,
                  event.contains(where: { !$0.isWhitespace }),
                  event.utf16.count <= AnalyticsLimits.maximumEventNameLength
            else {
                return .failure(.invalidParams)
            }
            let params = DappNativeBridge.trackParams(json["params"] as? [String: Any]).mapValues { value -> Any in
                (value as? String)?.redactingAddresses ?? value
            }
            return .success(.track(event: event, params: params as NSDictionary))
        default:
            return .failure(.unsupportedMethod)
        }
    }

    private static func ignored(_ reason: String) -> Request? {
        Log.d("keeper dapp bridge: message ignored: \(reason)")
        return nil
    }
}

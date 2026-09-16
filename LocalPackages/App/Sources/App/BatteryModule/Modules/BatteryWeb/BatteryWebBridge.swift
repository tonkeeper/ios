import Foundation
import KeeperCore
import TKLogging

/// Message protocol between the battery web page and the app: the page posts
/// `{"type": "get-data" | "refresh-data", "queryId", "accessToken"?}` through
/// `window.ReactNativeWebView.postMessage` and receives `{"queryId", "payload"}` back, where
/// `payload` is the JSON-encoded `BatteryWebAuthorization` as a string.
enum BatteryWebBridge {
    static let messageHandlerName = "battery"

    enum Method: String {
        case getData = "get-data"
        case refreshData = "refresh-data"
    }

    struct Request: Equatable {
        let queryId: String
        let method: Method
        let expiredAccessToken: String?
    }

    static func parse(_ body: Any) -> Request? {
        guard let string = body as? String,
              let data = string.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data)
        else {
            return ignored("invalid JSON")
        }
        guard let json = object as? [String: Any] else {
            return ignored("expected JSON object")
        }
        guard let queryId = json["queryId"] as? String, !queryId.isEmpty else {
            return ignored("missing or invalid queryId")
        }
        guard let method = (json["type"] as? String).flatMap(Method.init(rawValue:)) else {
            return ignored("unknown method, queryId=\(queryId)")
        }

        let expiredAccessToken: String?
        switch method {
        case .getData:
            expiredAccessToken = nil
        case .refreshData:
            guard let accessToken = json["accessToken"] as? String, !accessToken.isEmpty else {
                return ignored("missing or invalid accessToken, queryId=\(queryId)")
            }
            expiredAccessToken = accessToken
        }

        return Request(queryId: queryId, method: method, expiredAccessToken: expiredAccessToken)
    }

    static func response(queryId: String, authorization: BatteryWebAuthorization) -> String? {
        let payload: [String: String] = [
            "walletId": authorization.walletId,
            "deviceToken": authorization.deviceToken,
            "walletToken": authorization.walletToken,
        ]
        guard let payloadData = try? JSONSerialization.data(withJSONObject: payload),
              let payloadString = String(data: payloadData, encoding: .utf8),
              let responseData = try? JSONSerialization.data(withJSONObject: [
                  "queryId": queryId,
                  "payload": payloadString,
              ])
        else {
            return nil
        }
        return String(data: responseData, encoding: .utf8)
    }

    static func isTrustedOrigin(pageURL: URL?, startURL: URL) -> Bool {
        guard let pageURL,
              startURL.scheme?.lowercased() == "https",
              pageURL.scheme?.lowercased() == "https",
              let startHost = startURL.host, !startHost.isEmpty,
              let pageHost = pageURL.host,
              pageHost.caseInsensitiveCompare(startHost) == .orderedSame
        else {
            return false
        }
        return (pageURL.port ?? 443) == (startURL.port ?? 443)
    }

    private static func ignored(_ reason: String) -> Request? {
        Log.d("battery web bridge: message ignored: \(reason)")
        return nil
    }
}

import Foundation

/// The host side of the frame message channel: the script that exposes `window.MoonPayBridge` to
/// the page, the origin check for incoming script messages, and decoding of message bodies into
/// events for one channel.
public struct MoonPayFrameBridge: Sendable {
    public static let messageHandlerName = "MoonPayBridge"

    public static let userScriptSource = """
    window.MoonPayBridge = {
        postMessage: function(message) {
            window.webkit.messageHandlers.MoonPayBridge.postMessage(message);
        }
    };
    """

    public enum Inbound: Equatable, Sendable {
        case event(MoonPayFrameEvent)
        case foreignChannel(String)
        case malformed(String)
    }

    public let channelId: String
    public let trustedHost: String

    public init(channelId: String, trustedHost: String) {
        self.channelId = channelId
        self.trustedHost = trustedHost
    }

    public init(channelId: String, environment: MoonPayEnvironment) {
        self.init(channelId: channelId, trustedHost: environment.frameOrigin.host ?? "")
    }

    /// MoonPay posts from nested frames as well as the top document, so trust is decided by the
    /// posting frame's security origin rather than by "main frame only".
    public func isTrustedOrigin(scheme: String?, host: String?) -> Bool {
        guard let scheme, let host, !trustedHost.isEmpty else { return false }
        return scheme.caseInsensitiveCompare("https") == .orderedSame
            && host.caseInsensitiveCompare(trustedHost) == .orderedSame
    }

    public func receive(body: Any) -> Inbound {
        let jsonString: String
        if let string = body as? String {
            jsonString = string
        } else if JSONSerialization.isValidJSONObject(body),
                  let data = try? JSONSerialization.data(withJSONObject: body),
                  let string = String(data: data, encoding: .utf8)
        {
            jsonString = string
        } else {
            return .malformed("unsupported message body \(type(of: body))")
        }

        let message: MoonPayFrameMessage
        do {
            message = try MoonPayFrameMessage.decode(jsonString: jsonString)
        } catch {
            return .malformed(error.localizedDescription)
        }
        guard message.channelId == channelId else {
            return .foreignChannel(message.channelId)
        }
        do {
            return try .event(MoonPayFrameEvent(message: message))
        } catch {
            return .malformed(error.localizedDescription)
        }
    }
}

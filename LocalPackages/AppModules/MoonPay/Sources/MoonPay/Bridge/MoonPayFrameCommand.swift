import Foundation

/// Messages the host sends into a frame.
public enum MoonPayFrameCommand: Equatable, Sendable {
    /// Reply to the frame's `handshake`; nothing else happens until the frame receives it.
    case ack
    /// Replaces the quote of a payment frame (`buy`, `apple-pay`) before the current one expires.
    case setQuote(signature: String)

    public var kind: String {
        switch self {
        case .ack: "ack"
        case .setQuote: "setQuote"
        }
    }

    public func message(channelId: String) -> MoonPayFrameMessage {
        switch self {
        case .ack:
            MoonPayFrameMessage(kind: kind, channelId: channelId)
        case let .setQuote(signature):
            MoonPayFrameMessage(
                kind: kind,
                channelId: channelId,
                payload: .object(["quote": .object(["signature": .string(signature)])])
            )
        }
    }
}

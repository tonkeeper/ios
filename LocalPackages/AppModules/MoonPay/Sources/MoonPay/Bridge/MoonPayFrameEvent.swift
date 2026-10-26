import Foundation

/// A frame → host message decoded into the shapes documented per frame.
public enum MoonPayFrameEvent: Equatable, Sendable {
    case handshake
    case ready
    case complete(MoonPayFrameCompletion)
    case transactionCreated(MoonPayTransaction)
    case challenge(url: URL)
    /// The buy flow may attach resumption data to a cancellation.
    case cancelled(MoonPayJSONValue?)
    case buttonPressed
    case error(MoonPayFrameError.Remote)
    case unknown(kind: String, payload: MoonPayJSONValue?)

    public init(message: MoonPayFrameMessage) throws {
        let payload = message.payload
        switch message.kind {
        case "handshake":
            self = .handshake
        case "ready":
            self = .ready
        case "complete":
            self = try .complete(MoonPayFrameCompletion(payload: payload))
        case "transactionCreated":
            guard let transaction = payload?["transaction"] else {
                throw MoonPayFrameError.malformedMessage("transactionCreated without transaction")
            }
            self = try .transactionCreated(transaction.decode(MoonPayTransaction.self))
        case "challenge":
            guard let urlString = payload?["url"]?.stringValue, let url = URL(string: urlString) else {
                throw MoonPayFrameError.malformedMessage("challenge without url")
            }
            self = .challenge(url: url)
        case "cancelled":
            self = .cancelled(payload)
        case "buttonPressed":
            self = .buttonPressed
        case "error":
            self = .error(MoonPayFrameError.Remote(payload: payload))
        default:
            self = .unknown(kind: message.kind, payload: payload)
        }
    }

    public var name: String {
        switch self {
        case .handshake: "handshake"
        case .ready: "ready"
        case .complete: "complete"
        case .transactionCreated: "transactionCreated"
        case .challenge: "challenge"
        case .cancelled: "cancelled"
        case .buttonPressed: "buttonPressed"
        case .error: "error"
        case let .unknown(kind, _): kind
        }
    }
}

/// Payload of a `complete` event. The shape depends on the frame; the challenge frame adds a
/// `flow` discriminator.
public enum MoonPayFrameCompletion: Equatable, Sendable {
    /// `check-connection` and `connect`.
    case connection(MoonPayConnectionResult)
    /// `widget`, `buy`, `apple-pay` and a challenge with `flow: "buy"`.
    case transaction(MoonPayTransaction)
    /// `add-card`.
    case card(MoonPaySavedCard)
    /// A challenge with `flow: "identity"`.
    case identity(id: String)
    /// A challenge with `flow: "guest_checkout_limit_upgrade"`, or any other status-only payload.
    case status(String)
    case raw(MoonPayJSONValue?)

    public init(payload: MoonPayJSONValue?) throws {
        guard let payload, payload.objectValue != nil else {
            self = .raw(payload)
            return
        }
        if let flow = payload["flow"]?.stringValue {
            switch flow {
            case "buy":
                guard let transaction = payload["transaction"] else {
                    throw MoonPayFrameError.malformedMessage("buy challenge completed without transaction")
                }
                self = try .transaction(transaction.decode(MoonPayTransaction.self))
            case "identity":
                guard let identityId = payload["identityId"]?.stringValue else {
                    throw MoonPayFrameError.malformedMessage("identity challenge completed without identityId")
                }
                self = .identity(id: identityId)
            default:
                if let status = payload["status"]?.stringValue {
                    self = .status(status)
                } else {
                    self = .raw(payload)
                }
            }
            return
        }
        if let transaction = payload["transaction"] {
            self = try .transaction(transaction.decode(MoonPayTransaction.self))
        } else if let card = payload["card"] {
            self = try .card(card.decode(MoonPaySavedCard.self))
        } else if let status = payload["status"]?.stringValue {
            if MoonPayConnectionStatus(rawValue: status) != nil {
                self = try .connection(payload.decode(MoonPayConnectionResult.self))
            } else {
                self = .status(status)
            }
        } else {
            self = .raw(payload)
        }
    }
}

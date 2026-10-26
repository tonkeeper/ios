import Foundation
import TKKandelabrAPI
import TKLogging

protocol HermesCandleStreaming: AnyObject, Sendable {
    func watch(
        feedId: String,
        volumeFeedId: String,
        onUpdate: @escaping @Sendable (Components.Schemas.GetCandlesResponse) async -> Void,
        onVolumeUpdate: @escaping @Sendable (Components.Schemas.GetCandlesResponse) async -> Void,
        onSubscribed: @escaping @Sendable () async -> Void,
        onReconnecting: @escaping @Sendable () async -> Void,
        onRejected: @escaping @Sendable () async -> Void
    ) -> HermesCandleWatch
}

struct HermesCandleWatch: Sendable {
    private let onCancel: @Sendable () -> Void

    init(onCancel: @escaping @Sendable () -> Void) {
        self.onCancel = onCancel
    }

    func cancel() {
        onCancel()
    }
}

enum HermesCandleEvent: Equatable {
    case candles(feedId: String?, Components.Schemas.GetCandlesResponse)
    case subscribed(requestId: Int64?)
    case retryableFailure(requestId: Int64?)
    case rejected(requestId: Int64?)
    case ignored
}

enum HermesCandleCodec {
    static func event(from data: Data) -> HermesCandleEvent {
        let envelope: HermesInboundEnvelope<InboundPayload>
        do {
            envelope = try JSONDecoder().decode(HermesInboundEnvelope<InboundPayload>.self, from: data)
        } catch {
            Log.perps.w("hermes frame skipped — \(error)")
            return .ignored
        }

        if envelope.channel == HermesChannel.candles, envelope.message?.name == HermesMessageName.candlesPush {
            guard let data = envelope.message?.payload?.data else { return .ignored }
            return .candles(feedId: envelope.message?.payload?.feedId, data)
        }

        if envelope.channel == HermesChannel.subscribe,
           envelope.message?.name == HermesMessageName.subscribeResponse
        {
            return .subscribed(requestId: envelope.message?.reqid)
        }

        if envelope.channel == HermesChannel.subscribe,
           envelope.message?.name == HermesMessageName.errorResponse
           || envelope.message?.name == HermesMessageName.errorMessage
        {
            let code = envelope.message?.payload?.code
            if code == "already.subscribed" {
                return .subscribed(requestId: envelope.message?.reqid)
            }
            if let code, permanentFeedErrors.contains(code) {
                return .rejected(requestId: envelope.message?.reqid)
            }
            return .retryableFailure(requestId: envelope.message?.reqid)
        }

        return .ignored
    }

    private static let permanentFeedErrors: Set<String> = ["invalid.request", "not.found", "unauthorized"]
}

private struct InboundPayload: Decodable {
    let feedId: String?
    let data: Components.Schemas.GetCandlesResponse?
    let code: String?
}

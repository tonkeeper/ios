import Foundation
import TKKandelabrAPI
import TKLogging

protocol HermesCandleStreaming: AnyObject, Sendable {
    func watch(
        feedId: String,
        onUpdate: @escaping @Sendable (Components.Schemas.GetCandlesResponse) async -> Void,
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
    case candles(Components.Schemas.GetCandlesResponse)
    case subscribed(requestId: Int64?)
    case retryableFailure
    case rejected
    case ignored
}

enum HermesCandleCodec {
    static func request(
        channel: String,
        name: String,
        reqid: Int64,
        payload: [String: String]? = nil
    ) throws -> Data {
        try JSONEncoder().encode(
            HermesOutboundEnvelope(
                channel: channel,
                message: HermesOutboundMessage(name: name, reqid: reqid, payload: payload)
            )
        )
    }

    static func event(from data: Data) -> HermesCandleEvent {
        let envelope: HermesInboundEnvelope<InboundPayload>
        do {
            envelope = try JSONDecoder().decode(HermesInboundEnvelope<InboundPayload>.self, from: data)
        } catch {
            Log.w("🪵 Perps: hermes frame skipped — \(error)")
            return .ignored
        }

        if envelope.channel == HermesChannel.candles, envelope.message?.name == HermesMessageName.candlesPush {
            guard let data = envelope.message?.payload?.data else { return .ignored }
            return .candles(data)
        }

        if envelope.channel == HermesChannel.subscribe,
           envelope.message?.name == HermesMessageName.subscribeResponse
        {
            return .subscribed(requestId: envelope.message?.reqid)
        }

        if envelope.message?.name == HermesMessageName.errorResponse
            || envelope.message?.name == HermesMessageName.errorMessage
        {
            let code = envelope.message?.payload?.code
            let description = envelope.message?.payload?.description
            Log.w("🪵 Perps: hermes \(envelope.channel ?? "?") error — \(code ?? "") \(description ?? "")")
            if envelope.channel == HermesChannel.subscribe, code == "already.subscribed" {
                return .subscribed(requestId: envelope.message?.reqid)
            }
            if envelope.channel == HermesChannel.subscribe, let code, permanentFeedErrors.contains(code) {
                return .rejected
            }
            if envelope.channel == HermesChannel.subscribe {
                return .retryableFailure
            }
        }

        return .ignored
    }

    private static let permanentFeedErrors: Set<String> = ["invalid.request", "not.found", "unauthorized"]
}

private struct InboundPayload: Decodable {
    let data: Components.Schemas.GetCandlesResponse?
    let code: String?
    let description: String?
}

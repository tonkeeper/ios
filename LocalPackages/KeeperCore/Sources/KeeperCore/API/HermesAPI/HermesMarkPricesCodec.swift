import Foundation
import TKLogging

struct HermesTickerPrice: Equatable, Sendable {
    let ticker: String
    let price: String
}

enum HermesMarkPricesEvent: Equatable {
    case prices([HermesTickerPrice])
    case subscribed
    /// The requested ticker set was refused (e.g. a ticker failed server-side
    /// validation). The connection and the previously accepted subscription stay
    /// intact, so this only means "that set didn't take".
    case declined
    case retryableFailure
    case rejected
    case ignored
}

struct HermesMarkPricesFrame {
    let event: HermesMarkPricesEvent
    let requestId: Int64?
}

enum HermesMarkPricesCodec {
    static func subscribeRequest(tickers: [String], cooldown: String, reqid: Int64) throws -> Data {
        try JSONEncoder().encode(
            HermesOutboundEnvelope(
                channel: HermesMarkPricesChannel.subscribe,
                message: HermesOutboundMessage(
                    name: HermesMarkPricesMessageName.subscribe,
                    reqid: reqid,
                    payload: SubscribePayload(tickers: tickers, cooldown: cooldown)
                )
            )
        )
    }

    static func pingRequest(reqid: Int64) throws -> Data {
        try JSONEncoder().encode(
            HermesOutboundEnvelope<SubscribePayload>(
                channel: HermesChannel.ping,
                message: HermesOutboundMessage(name: HermesMessageName.ping, reqid: reqid, payload: nil)
            )
        )
    }

    static func event(from data: Data) -> HermesMarkPricesEvent {
        frame(from: data).event
    }

    static func frame(from data: Data) -> HermesMarkPricesFrame {
        let envelope: HermesInboundEnvelope<InboundPayload>
        do {
            envelope = try JSONDecoder().decode(HermesInboundEnvelope<InboundPayload>.self, from: data)
        } catch {
            Log.w("🪵 Perps: hermes prices frame skipped — \(error)")
            return HermesMarkPricesFrame(event: .ignored, requestId: nil)
        }

        if envelope.channel == HermesMarkPricesChannel.prices,
           envelope.message?.name == HermesMarkPricesMessageName.pricesPush
        {
            let prices = (envelope.message?.payload?.markPrices ?? []).compactMap { entry -> HermesTickerPrice? in
                guard let ticker = entry.ticker, let price = entry.markPrice else { return nil }
                return HermesTickerPrice(ticker: ticker, price: price)
            }
            return HermesMarkPricesFrame(event: .prices(prices), requestId: envelope.message?.reqid)
        }

        if envelope.channel == HermesMarkPricesChannel.subscribe,
           envelope.message?.name == HermesMarkPricesMessageName.subscribeResponse
        {
            return HermesMarkPricesFrame(event: .subscribed, requestId: envelope.message?.reqid)
        }

        if envelope.message?.name == HermesMessageName.errorResponse
            || envelope.message?.name == HermesMessageName.errorMessage
        {
            let code = envelope.message?.payload?.code
            let description = envelope.message?.payload?.description
            Log.w("🪵 Perps: hermes \(envelope.channel ?? "?") error — \(code ?? "") \(description ?? "")")
            if envelope.channel == HermesMarkPricesChannel.subscribe, code == "already.subscribed" {
                return HermesMarkPricesFrame(event: .subscribed, requestId: envelope.message?.reqid)
            }
            if envelope.channel == HermesMarkPricesChannel.subscribe, code == "unauthorized" {
                // The channel is gated for this client; retrying within the session cannot
                // succeed — degrade to REST prices instead of hammering the socket.
                return HermesMarkPricesFrame(event: .rejected, requestId: envelope.message?.reqid)
            }
            if envelope.channel == HermesMarkPricesChannel.subscribe, let code, declinedErrors.contains(code) {
                // A refused subscribe leaves the previously accepted set delivering,
                // so only this request is lost, not the stream.
                return HermesMarkPricesFrame(event: .declined, requestId: envelope.message?.reqid)
            }
            if envelope.channel == HermesMarkPricesChannel.subscribe {
                return HermesMarkPricesFrame(event: .retryableFailure, requestId: envelope.message?.reqid)
            }
        }

        return HermesMarkPricesFrame(event: .ignored, requestId: envelope.message?.reqid)
    }

    private static let declinedErrors: Set<String> = ["invalid.request", "not.found"]
}

enum HermesMarkPricesChannel {
    static let subscribe = "subscribeMarkPrices"
    static let prices = "markPrices"
}

enum HermesMarkPricesMessageName {
    static let subscribe = "subscribeMarkPricesRequest"
    static let subscribeResponse = "subscribeMarkPricesResponse"
    static let pricesPush = "markPricesMessage"
}

private struct SubscribePayload: Encodable {
    let tickers: [String]
    let cooldown: String
}

private struct InboundPayload: Decodable {
    let markPrices: [InboundTickerPrice]?
    let code: String?
    let description: String?
}

private struct InboundTickerPrice: Decodable {
    let ticker: String?
    let markPrice: String?
}

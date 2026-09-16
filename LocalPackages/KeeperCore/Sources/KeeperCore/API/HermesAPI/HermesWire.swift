import Foundation

enum HermesSocketError: Error {
    case badURL
}

struct HermesSocketFactory: @unchecked Sendable {
    private let hostProvider: APIHostProvider
    private let urlSession: URLSession

    init(hostProvider: APIHostProvider, urlSession: URLSession) {
        self.hostProvider = hostProvider
        self.urlSession = urlSession
    }

    func makeTask() async throws -> URLSessionWebSocketTask {
        let host = await hostProvider.basePath
        guard let hostURL = URL(string: host), let url = HermesEndpoint.webSocketURL(from: hostURL) else {
            throw HermesSocketError.badURL
        }
        return urlSession.webSocketTask(with: url)
    }
}

enum HermesChannel {
    static let ping = "ping"
    static let subscribe = "subscribeCandleFeed"
    static let unsubscribe = "unsubscribeCandleFeed"
    static let candles = "candles"
}

enum HermesMessageName {
    static let ping = "ping"
    static let subscribe = "subscribeCandleFeedRequest"
    static let subscribeResponse = "subscribeCandleFeedResponse"
    static let unsubscribe = "unsubscribeCandleFeedRequest"
    static let candlesPush = "candlesFeedMessage"
    static let errorResponse = "errorResponse"
    static let errorMessage = "errorMessage"
}

struct HermesOutboundEnvelope<Payload: Encodable>: Encodable {
    let channel: String
    let message: HermesOutboundMessage<Payload>
}

struct HermesOutboundMessage<Payload: Encodable>: Encodable {
    let name: String
    let reqid: Int64
    let payload: Payload?

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(reqid, forKey: .reqid)
        if let payload {
            try container.encode(payload, forKey: .payload)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case name, reqid, payload
    }
}

struct HermesInboundEnvelope<Payload: Decodable>: Decodable {
    let channel: String?
    let message: HermesInboundMessage<Payload>?
}

struct HermesInboundMessage<Payload: Decodable>: Decodable {
    let name: String?
    let reqid: Int64?
    let payload: Payload?
}

extension URLSessionWebSocketTask.Message {
    var data: Data? {
        switch self {
        case let .data(data):
            return data
        case let .string(text):
            return Data(text.utf8)
        @unknown default:
            return nil
        }
    }
}

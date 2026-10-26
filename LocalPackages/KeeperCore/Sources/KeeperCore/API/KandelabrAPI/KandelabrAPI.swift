import Foundation
import TKKandelabrAPI

protocol KandelabrAPI: Sendable {
    func candles(
        tickers: [String],
        resolution: String,
        limit: Int32?,
        endTs: Int64?
    ) async throws(KandelabrAPIError) -> [Components.Schemas.GetCandlesResponse]
}

/// `APIHostProvider` is not `Sendable`: its providers read the unannotated `Configuration`.
struct KandelabrAPIImplementation: @unchecked Sendable {
    private let hostProvider: APIHostProvider
    private let urlSession: URLSession

    init(
        hostProvider: APIHostProvider,
        urlSession: URLSession
    ) {
        self.hostProvider = hostProvider
        self.urlSession = urlSession
    }
}

extension KandelabrAPIImplementation: KandelabrAPI {
    func candles(
        tickers: [String],
        resolution: String,
        limit: Int32?,
        endTs: Int64?
    ) async throws(KandelabrAPIError) -> [Components.Schemas.GetCandlesResponse] {
        guard let resolutionPayload = Components.Schemas.GetCandlesRequest.resolutionPayload(rawValue: resolution) else {
            throw .badRequest
        }
        let client: Client
        do {
            client = try await Client(hostProvider: hostProvider, urlSession: urlSession)
        } catch {
            throw .badURL
        }

        let response: Operations.getCandlesBatch.Output
        do {
            response = try await client.getCandlesBatch(
                body: .json(
                    .init(requests: tickers.map {
                        .init(ticker: $0, resolution: resolutionPayload, end_ts: endTs, limit: limit)
                    })
                )
            )
        } catch {
            throw .transport(error)
        }

        switch response {
        case let .ok(ok):
            do {
                return try ok.body.json.responses
            } catch {
                throw .badResponse(error)
            }
        case .badRequest:
            throw .badRequest
        case let .undocumented(statusCode, _):
            throw .badStatus(statusCode)
        }
    }
}

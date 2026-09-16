import Foundation
import TKKandelabrAPI

protocol KandelabrAPI {
    func candles(
        ticker: String,
        resolution: String,
        limit: Int32?,
        startTs: Int64?,
        endTs: Int64?
    ) async throws(KandelabrAPIError) -> Components.Schemas.GetCandlesResponse
}

struct KandelabrAPIImplementation {
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
        ticker: String,
        resolution: String,
        limit: Int32?,
        startTs: Int64?,
        endTs: Int64?
    ) async throws(KandelabrAPIError) -> Components.Schemas.GetCandlesResponse {
        guard let resolutionPayload = Components.Schemas.GetCandlesRequest.resolutionPayload(rawValue: resolution) else {
            throw .badRequest
        }
        let client: Client
        do {
            client = try await Client(hostProvider: hostProvider, urlSession: urlSession)
        } catch {
            throw .badURL
        }

        let response: Operations.getCandles.Output
        do {
            response = try await client.getCandles(
                body: .json(
                    .init(
                        ticker: ticker,
                        resolution: resolutionPayload,
                        start_ts: startTs,
                        end_ts: endTs,
                        limit: limit
                    )
                )
            )
        } catch {
            throw .transport(error)
        }

        switch response {
        case let .ok(ok):
            do {
                return try ok.body.json
            } catch {
                throw .badResponse(error)
            }
        case .badRequest:
            throw .badRequest
        case .notFound:
            throw .notFound
        case .internalServerError:
            throw .badStatus(500)
        case let .undocumented(statusCode, _):
            throw .badStatus(statusCode)
        }
    }
}

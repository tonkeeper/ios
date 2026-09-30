import Foundation
import TKPerpsAPI

struct PerpsAPIImplementation: PerpsAPI {
    private let makeClient: (String) async throws -> Client

    init(makeClient: @escaping (String) async throws -> Client) {
        self.makeClient = makeClient
    }

    func account(walletId: String) async throws -> Components.Schemas.Account {
        let client = try await client(walletId: walletId)
        let response: Operations.getAccount.Output
        do {
            response = try await client.getAccount(headers: accountHeaders(walletId: walletId))
        } catch {
            throw PerpsAPIError.transport(underlying: error)
        }
        switch response {
        case let .ok(ok): return try decode(ok.body.json)
        case let .badRequest(payload): throw status(400, payload)
        case .unauthorized(_), .forbidden: throw PerpsAPIError.unauthorized
        case .internalServerError: throw PerpsAPIError.badStatus(.undecoded(500, message: "internal error"))
        case .serviceUnavailable: throw PerpsAPIError.badStatus(.undecoded(503, message: "upstream unavailable"))
        case let .undocumented(statusCode, _): throw PerpsAPIError.badStatus(.undecoded(statusCode, message: "undocumented"))
        }
    }

    func bindAccount(
        walletId: String,
        request: Components.Schemas.BindAccountRequest
    ) async throws -> Components.Schemas.Account {
        let client = try await client(walletId: walletId)
        let response: Operations.bindAccount.Output
        do {
            response = try await client.bindAccount(
                headers: bindHeaders(walletId: walletId),
                body: .json(request)
            )
        } catch {
            throw PerpsAPIError.transport(underlying: error)
        }
        switch response {
        case let .ok(ok): return try decode(ok.body.json)
        case let .badRequest(payload): throw status(400, payload)
        case .unauthorized(_), .forbidden: throw PerpsAPIError.unauthorized
        case let .conflict(payload): throw failure(409, try? payload.body.json)
        case .internalServerError: throw PerpsAPIError.badStatus(.undecoded(500, message: "internal error"))
        case .serviceUnavailable: throw PerpsAPIError.badStatus(.undecoded(503, message: "upstream unavailable"))
        case let .undocumented(statusCode, _): throw PerpsAPIError.badStatus(.undecoded(statusCode, message: "undocumented"))
        }
    }

    func tradingScreen(
        walletId: String,
        marketId: Int64
    ) async throws -> Components.Schemas.TradingScreen {
        let client = try await client(walletId: walletId)
        let response: Operations.getTradingScreen.Output
        do {
            response = try await client.getTradingScreen(
                query: .init(market: Int(marketId)),
                headers: headers(walletId: walletId)
            )
        } catch {
            throw PerpsAPIError.transport(underlying: error)
        }
        switch response {
        case let .ok(ok):
            return try decode(ok.body.json)
        case let .badRequest(payload):
            throw status(400, payload)
        case .unauthorized(_), .forbidden:
            throw PerpsAPIError.unauthorized
        case .notFound:
            throw PerpsAPIError.notFound
        case .internalServerError:
            throw PerpsAPIError.badStatus(.undecoded(500, message: "internal error"))
        case .serviceUnavailable:
            throw PerpsAPIError.badStatus(.undecoded(503, message: "upstream unavailable"))
        case let .undocumented(statusCode, _):
            throw PerpsAPIError.badStatus(.undecoded(statusCode, message: "undocumented"))
        }
    }

    func truncatedOrderBook(
        walletId: String,
        marketId: Int64,
        side: Operations.getTruncatedOrderBook.Input.Query.sidePayload,
        feeRate: String,
        notional: String
    ) async throws -> Components.Schemas.TruncatedOrderBook {
        let client = try await client(walletId: walletId)
        let response: Operations.getTruncatedOrderBook.Output
        do {
            response = try await client.getTruncatedOrderBook(
                query: .init(market: Int32(clamping: marketId), side: side, fee_rate: feeRate, notional: notional),
                headers: headers(walletId: walletId)
            )
        } catch {
            throw PerpsAPIError.transport(underlying: error)
        }
        switch response {
        case let .ok(ok):
            return try decode(ok.body.json)
        case let .badRequest(payload):
            throw status(400, payload)
        case .unauthorized(_), .forbidden:
            throw PerpsAPIError.unauthorized
        case .internalServerError:
            throw PerpsAPIError.badStatus(.undecoded(500, message: "internal error"))
        case .serviceUnavailable:
            throw PerpsAPIError.badStatus(.undecoded(503, message: "upstream unavailable"))
        case let .undocumented(statusCode, _):
            throw PerpsAPIError.badStatus(.undecoded(statusCode, message: "undocumented"))
        }
    }

    func nextNonce(
        walletId: String,
        apiKeyIndex: Int
    ) async throws -> Components.Schemas.NextNonce {
        let client = try await client(walletId: walletId)
        let response: Operations.getNextNonce.Output
        do {
            response = try await client.getNextNonce(
                query: .init(api_key_index: apiKeyIndex),
                headers: headers(walletId: walletId)
            )
        } catch {
            throw PerpsAPIError.transport(underlying: error)
        }
        switch response {
        case let .ok(ok):
            return try decode(ok.body.json)
        case let .badRequest(payload):
            throw status(400, payload)
        case .unauthorized(_), .forbidden:
            throw PerpsAPIError.unauthorized
        case .conflict:
            throw PerpsAPIError.conflict
        case .internalServerError:
            throw PerpsAPIError.badStatus(.undecoded(500, message: "internal error"))
        case .serviceUnavailable:
            throw PerpsAPIError.badStatus(.undecoded(503, message: "upstream unavailable"))
        case let .undocumented(statusCode, _):
            throw PerpsAPIError.badStatus(.undecoded(statusCode, message: "undocumented"))
        }
    }

    func sendTransactions(
        walletId: String,
        transactions: [Components.Schemas.SignedTransaction]
    ) async throws -> Components.Schemas.SendTransactionsResponse {
        let client = try await client(walletId: walletId)
        let response: Operations.sendTransactions.Output
        do {
            response = try await client.sendTransactions(
                headers: headers(walletId: walletId),
                body: .json(.init(transactions: transactions))
            )
        } catch {
            throw PerpsAPIError.transport(underlying: error)
        }
        switch response {
        case let .ok(ok):
            return try decode(ok.body.json)
        case let .badRequest(payload):
            throw sendStatus(400, payload)
        case .unauthorized(_), .forbidden:
            throw PerpsAPIError.unauthorized
        case .conflict:
            throw PerpsAPIError.conflict
        case .internalServerError:
            throw PerpsAPIError.badStatus(.undecoded(500, message: "internal error"))
        case let .serviceUnavailable(payload):
            throw sendUnavailable(payload)
        case let .undocumented(statusCode, _):
            throw PerpsAPIError.badStatus(.undecoded(statusCode, message: "undocumented"))
        }
    }

    func portfolioScreen(walletId: String) async throws -> Components.Schemas.PortfolioScreen {
        let client = try await client(walletId: walletId)
        let response: Operations.getPortfolioScreen.Output
        do {
            response = try await client.getPortfolioScreen(headers: headers(walletId: walletId))
        } catch {
            throw PerpsAPIError.transport(underlying: error)
        }
        switch response {
        case let .ok(ok):
            return try decode(ok.body.json)
        case let .badRequest(payload):
            throw status(400, payload)
        case .unauthorized(_), .forbidden:
            throw PerpsAPIError.unauthorized
        case .internalServerError:
            throw PerpsAPIError.badStatus(.undecoded(500, message: "internal error"))
        case .serviceUnavailable:
            throw PerpsAPIError.badStatus(.undecoded(503, message: "upstream unavailable"))
        case let .undocumented(statusCode, _):
            throw PerpsAPIError.badStatus(.undecoded(statusCode, message: "undocumented"))
        }
    }

    func listOpenPositions(walletId: String) async throws -> Components.Schemas.OpenPositionsPage {
        let client = try await client(walletId: walletId)
        let response: Operations.listOpenPositions.Output
        do {
            response = try await client.listOpenPositions(headers: headers(walletId: walletId))
        } catch {
            throw PerpsAPIError.transport(underlying: error)
        }
        switch response {
        case let .ok(ok):
            return try decode(ok.body.json)
        case let .badRequest(payload):
            throw status(400, payload)
        case .unauthorized(_), .forbidden:
            throw PerpsAPIError.unauthorized
        case .internalServerError:
            throw PerpsAPIError.badStatus(.undecoded(500, message: "internal error"))
        case .serviceUnavailable:
            throw PerpsAPIError.badStatus(.undecoded(503, message: "upstream unavailable"))
        case let .undocumented(statusCode, _):
            throw PerpsAPIError.badStatus(.undecoded(statusCode, message: "undocumented"))
        }
    }

    func getOpenPosition(
        walletId: String,
        id: String
    ) async throws -> Components.Schemas.OpenPositionDetail {
        let client = try await client(walletId: walletId)
        let response: Operations.getOpenPosition.Output
        do {
            response = try await client.getOpenPosition(
                path: .init(id: id),
                headers: headers(walletId: walletId)
            )
        } catch {
            throw PerpsAPIError.transport(underlying: error)
        }
        switch response {
        case let .ok(ok):
            return try decode(ok.body.json)
        case let .badRequest(payload):
            throw status(400, payload)
        case .unauthorized(_), .forbidden:
            throw PerpsAPIError.unauthorized
        case .notFound:
            throw PerpsAPIError.notFound
        case .internalServerError:
            throw PerpsAPIError.badStatus(.undecoded(500, message: "internal error"))
        case .serviceUnavailable:
            throw PerpsAPIError.badStatus(.undecoded(503, message: "upstream unavailable"))
        case let .undocumented(statusCode, _):
            throw PerpsAPIError.badStatus(.undecoded(statusCode, message: "undocumented"))
        }
    }

    func positionState(
        walletId: String,
        id: String,
        clientOrderIndex: Int64?
    ) async throws -> Components.Schemas.PositionState {
        let client = try await client(walletId: walletId)
        let response: Operations.getPositionState.Output
        do {
            response = try await client.getPositionState(
                path: .init(id: id),
                query: .init(client_order_index: clientOrderIndex),
                headers: headers(walletId: walletId)
            )
        } catch {
            throw PerpsAPIError.transport(underlying: error)
        }
        switch response {
        case let .ok(ok):
            return try decode(ok.body.json)
        case let .badRequest(payload):
            throw status(400, payload)
        case .unauthorized(_), .forbidden:
            throw PerpsAPIError.unauthorized
        case .internalServerError:
            throw PerpsAPIError.badStatus(.undecoded(500, message: "internal error"))
        case .serviceUnavailable:
            throw PerpsAPIError.badStatus(.undecoded(503, message: "upstream unavailable"))
        case let .undocumented(statusCode, _):
            throw PerpsAPIError.badStatus(.undecoded(statusCode, message: "undocumented"))
        }
    }

    func activity(
        walletId: String,
        marketId: Int64?,
        limit: Int
    ) async throws -> Components.Schemas.ActivityPage {
        let client = try await client(walletId: walletId)
        let response: Operations.getActivity.Output
        do {
            response = try await client.getActivity(
                query: .init(market: marketId.map(Int.init), limit: limit),
                headers: headers(walletId: walletId)
            )
        } catch {
            throw PerpsAPIError.transport(underlying: error)
        }
        switch response {
        case let .ok(ok):
            return try decode(ok.body.json)
        case let .badRequest(payload):
            throw status(400, payload)
        case .unauthorized(_), .forbidden:
            throw PerpsAPIError.unauthorized
        case .internalServerError:
            throw PerpsAPIError.badStatus(.undecoded(500, message: "internal error"))
        case .serviceUnavailable:
            throw PerpsAPIError.badStatus(.undecoded(503, message: "upstream unavailable"))
        case let .undocumented(statusCode, _):
            throw PerpsAPIError.badStatus(.undecoded(statusCode, message: "undocumented"))
        }
    }
}

private extension PerpsAPIImplementation {
    /// The spec requires the header, but the credential is minted per request by
    /// `WalletAuthClientMiddlewares`, which also re-mints it after a 401. It travels
    /// empty from here and is overwritten there.
    static let walletAuthorizationSetByMiddleware = ""

    func client(walletId: String) async throws -> Client {
        do {
            return try await makeClient(walletId)
        } catch let error as PerpsAPIError {
            throw error
        } catch {
            throw PerpsAPIError.badUrl(underlying: error)
        }
    }

    func accountHeaders(walletId: String) -> Operations.getAccount.Input.Headers {
        .init(
            X_hyphen_Wallet_hyphen_Id: walletId,
            X_hyphen_Wallet_hyphen_Authorization: Self.walletAuthorizationSetByMiddleware
        )
    }

    func bindHeaders(walletId: String) -> Operations.bindAccount.Input.Headers {
        .init(
            X_hyphen_Wallet_hyphen_Id: walletId,
            X_hyphen_Wallet_hyphen_Authorization: Self.walletAuthorizationSetByMiddleware
        )
    }

    func headers(walletId: String) -> Operations.getTradingScreen.Input.Headers {
        .init(
            X_hyphen_Wallet_hyphen_Id: walletId,
            X_hyphen_Wallet_hyphen_Authorization: Self.walletAuthorizationSetByMiddleware
        )
    }

    func headers(walletId: String) -> Operations.getTruncatedOrderBook.Input.Headers {
        .init(
            X_hyphen_Wallet_hyphen_Id: walletId,
            X_hyphen_Wallet_hyphen_Authorization: Self.walletAuthorizationSetByMiddleware
        )
    }

    func headers(walletId: String) -> Operations.getNextNonce.Input.Headers {
        .init(
            X_hyphen_Wallet_hyphen_Id: walletId,
            X_hyphen_Wallet_hyphen_Authorization: Self.walletAuthorizationSetByMiddleware
        )
    }

    func headers(walletId: String) -> Operations.sendTransactions.Input.Headers {
        .init(
            X_hyphen_Wallet_hyphen_Id: walletId,
            X_hyphen_Wallet_hyphen_Authorization: Self.walletAuthorizationSetByMiddleware
        )
    }

    func headers(walletId: String) -> Operations.getPortfolioScreen.Input.Headers {
        .init(
            X_hyphen_Wallet_hyphen_Id: walletId,
            X_hyphen_Wallet_hyphen_Authorization: Self.walletAuthorizationSetByMiddleware
        )
    }

    func headers(walletId: String) -> Operations.listOpenPositions.Input.Headers {
        .init(
            X_hyphen_Wallet_hyphen_Id: walletId,
            X_hyphen_Wallet_hyphen_Authorization: Self.walletAuthorizationSetByMiddleware
        )
    }

    func headers(walletId: String) -> Operations.getOpenPosition.Input.Headers {
        .init(
            X_hyphen_Wallet_hyphen_Id: walletId,
            X_hyphen_Wallet_hyphen_Authorization: Self.walletAuthorizationSetByMiddleware
        )
    }

    func headers(walletId: String) -> Operations.getPositionState.Input.Headers {
        .init(
            X_hyphen_Wallet_hyphen_Id: walletId,
            X_hyphen_Wallet_hyphen_Authorization: Self.walletAuthorizationSetByMiddleware
        )
    }

    func headers(walletId: String) -> Operations.getActivity.Input.Headers {
        .init(
            X_hyphen_Wallet_hyphen_Id: walletId,
            X_hyphen_Wallet_hyphen_Authorization: Self.walletAuthorizationSetByMiddleware
        )
    }

    func decode<T>(_ body: @autoclosure () throws -> T) throws -> T {
        do {
            return try body()
        } catch {
            throw PerpsAPIError.badResponse(underlying: error)
        }
    }

    func status(_ httpStatus: Int, _ payload: Components.Responses.BadRequest) -> PerpsAPIError {
        failure(httpStatus, try? payload.body.json)
    }

    func sendStatus(_ httpStatus: Int, _ payload: Operations.sendTransactions.Output.BadRequest) -> PerpsAPIError {
        failure(httpStatus, try? payload.body.json)
    }

    func sendUnavailable(_ payload: Operations.sendTransactions.Output.ServiceUnavailable) -> PerpsAPIError {
        failure(503, try? payload.body.json)
    }

    func failure(_ httpStatus: Int, _ body: Components.Schemas.ErrorResponse?) -> PerpsAPIError {
        guard let body else {
            return .badStatus(.undecoded(httpStatus, message: "unreadable error body"))
        }
        return .badStatus(PerpsAPIFailure(httpStatus: httpStatus, body: body))
    }
}

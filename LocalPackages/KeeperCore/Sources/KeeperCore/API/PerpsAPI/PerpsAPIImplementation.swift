import Foundation
import OpenAPIRuntime
import TKPerpsAPI

struct PerpsAPIImplementation: PerpsAPI {
    private let makeClient: (String) async throws -> Client

    init(makeClient: @escaping (String) async throws -> Client) {
        self.makeClient = makeClient
    }

    func account(walletId: String) async throws -> Components.Schemas.Account {
        try await retrying {
            let client = try await client(walletId: walletId)
            let response: Operations.getAccount.Output
            do {
                response = try await client.getAccount()
            } catch {
                throw PerpsAPIError.transport(underlying: error)
            }
            switch response {
            case let .ok(ok): return try decode(ok.body.json)
            case let .badRequest(payload): throw status(400, payload)
            case .unauthorized(_), .forbidden: throw PerpsAPIError.unauthorized
            case let .internalServerError(payload): throw failure(500, try? payload.body.json)
            case let .serviceUnavailable(payload): throw failure(503, try? payload.body.json)
            case let .undocumented(statusCode, _): throw PerpsAPIError.badStatus(.undecoded(statusCode, message: "undocumented"))
            }
        }
    }

    func integrator(walletId: String) async throws -> Components.Schemas.Integrator {
        try await retrying {
            let client = try await client(walletId: walletId)
            let response: Operations.getIntegrator.Output
            do {
                response = try await client.getIntegrator()
            } catch {
                throw PerpsAPIError.transport(underlying: error)
            }
            switch response {
            case let .ok(ok): return try decode(ok.body.json)
            case let .badRequest(payload): throw status(400, payload)
            case .unauthorized(_), .forbidden: throw PerpsAPIError.unauthorized
            case let .internalServerError(payload): throw failure(500, try? payload.body.json)
            case let .serviceUnavailable(payload): throw failure(503, try? payload.body.json)
            case let .undocumented(statusCode, _): throw PerpsAPIError.badStatus(.undecoded(statusCode, message: "undocumented"))
            }
        }
    }

    func bindAccount(
        walletId: String,
        request: Components.Schemas.BindAccountRequest
    ) async throws -> Components.Schemas.Account {
        try await retrying {
            let client = try await client(walletId: walletId)
            let response: Operations.bindAccount.Output
            do {
                response = try await client.bindAccount(
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
            case let .internalServerError(payload): throw failure(500, try? payload.body.json)
            case let .serviceUnavailable(payload): throw failure(503, try? payload.body.json)
            case let .undocumented(statusCode, _): throw PerpsAPIError.badStatus(.undecoded(statusCode, message: "undocumented"))
            }
        }
    }

    func tradingScreen(
        walletId: String,
        marketId: Int64
    ) async throws -> Components.Schemas.TradingScreen {
        try await retrying {
            let client = try await client(walletId: walletId)
            let response: Operations.getTradingScreen.Output
            do {
                response = try await client.getTradingScreen(
                    query: .init(market: Int(marketId))
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
            case let .internalServerError(payload):
                throw failure(500, try? payload.body.json)
            case let .serviceUnavailable(payload):
                throw failure(503, try? payload.body.json)
            case let .undocumented(statusCode, _):
                throw PerpsAPIError.badStatus(.undecoded(statusCode, message: "undocumented"))
            }
        }
    }

    func truncatedOrderBook(
        walletId: String,
        marketId: Int64,
        side: Operations.getTruncatedOrderBook.Input.Query.sidePayload,
        feeRate: String,
        notional: String
    ) async throws -> Components.Schemas.TruncatedOrderBook {
        try await retrying {
            let client = try await client(walletId: walletId)
            let response: Operations.getTruncatedOrderBook.Output
            do {
                response = try await client.getTruncatedOrderBook(
                    query: .init(market: Int32(clamping: marketId), side: side, fee_rate: feeRate, notional: notional)
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
            case let .internalServerError(payload):
                throw failure(500, try? payload.body.json)
            case let .serviceUnavailable(payload):
                throw failure(503, try? payload.body.json)
            case let .undocumented(statusCode, _):
                throw PerpsAPIError.badStatus(.undecoded(statusCode, message: "undocumented"))
            }
        }
    }

    func nextNonce(
        walletId: String,
        apiKeyIndex: Int
    ) async throws -> Components.Schemas.NextNonce {
        try await retrying {
            let client = try await client(walletId: walletId)
            let response: Operations.getNextNonce.Output
            do {
                response = try await client.getNextNonce(
                    query: .init(api_key_index: apiKeyIndex)
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
            case let .internalServerError(payload):
                throw failure(500, try? payload.body.json)
            case let .serviceUnavailable(payload):
                throw failure(503, try? payload.body.json)
            case let .undocumented(statusCode, _):
                throw PerpsAPIError.badStatus(.undecoded(statusCode, message: "undocumented"))
            }
        }
    }

    func issueReadOnlyToken(
        walletId: String,
        lighterAuth: String
    ) async throws -> Components.Schemas.IssuedRoToken {
        try await retrying {
            let client = try await client(walletId: walletId)
            let response: Operations.issueRoToken.Output
            do {
                response = try await client.issueRoToken(
                    body: .json(.init(lighter_auth: lighterAuth))
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
            case let .internalServerError(payload):
                throw failure(500, try? payload.body.json)
            case let .serviceUnavailable(payload):
                throw failure(503, try? payload.body.json)
            case let .undocumented(statusCode, _):
                throw PerpsAPIError.badStatus(.undecoded(statusCode, message: "undocumented"))
            }
        }
    }

    func accountTier(walletId: String) async throws -> Components.Schemas.AccountTier {
        try await retrying {
            let client = try await client(walletId: walletId)
            let response: Operations.getAccountTier.Output
            do {
                response = try await client.getAccountTier()
            } catch {
                throw PerpsAPIError.transport(underlying: error)
            }
            switch response {
            case let .ok(ok): return try decode(ok.body.json)
            case let .badRequest(payload): throw status(400, payload)
            case .unauthorized(_), .forbidden: throw PerpsAPIError.unauthorized
            case .conflict: throw PerpsAPIError.conflict
            case let .internalServerError(payload): throw failure(500, try? payload.body.json)
            case let .serviceUnavailable(payload): throw failure(503, try? payload.body.json)
            case let .undocumented(statusCode, _): throw PerpsAPIError.badStatus(.undecoded(statusCode, message: "undocumented"))
            }
        }
    }

    func changeAccountTier(
        walletId: String,
        lighterAuth: String,
        newTier: String
    ) async throws {
        try await retrying {
            let client = try await client(walletId: walletId)
            let response: Operations.changeAccountTier.Output
            do {
                response = try await client.changeAccountTier(
                    body: .json(.init(lighter_auth: lighterAuth, new_tier: newTier))
                )
            } catch {
                throw PerpsAPIError.transport(underlying: error)
            }
            switch response {
            case .noContent: return
            case let .badRequest(payload): throw failure(400, try? payload.body.json)
            case .unauthorized(_), .forbidden: throw PerpsAPIError.unauthorized
            case .conflict: throw PerpsAPIError.conflict
            case let .internalServerError(payload): throw failure(500, try? payload.body.json)
            case let .serviceUnavailable(payload): throw failure(503, try? payload.body.json)
            case let .undocumented(statusCode, _): throw PerpsAPIError.badStatus(.undecoded(statusCode, message: "undocumented"))
            }
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
        case let .conflict(payload):
            throw failure(409, try? payload.body.json)
        case let .internalServerError(payload):
            throw failure(500, try? payload.body.json)
        case let .serviceUnavailable(payload):
            throw sendUnavailable(payload)
        case let .undocumented(statusCode, _):
            throw PerpsAPIError.badStatus(.undecoded(statusCode, message: "undocumented"))
        }
    }

    func openDeposit(
        walletId: String,
        request: Components.Schemas.OpenDepositRequest
    ) async throws -> Components.Schemas.Deposit {
        try await retrying {
            let client = try await client(walletId: walletId)
            let response: Operations.openDeposit.Output
            do {
                response = try await client.openDeposit(
                    body: .json(request)
                )
            } catch {
                throw transportOrStatus(error)
            }
            switch response {
            case let .ok(ok): return try decode(ok.body.json)
            case let .badRequest(payload): throw status(400, payload)
            // Unlike the other operations, a refused proof here parks the deposit for the user
            // to authorize again, while an expired token is the client's own to refresh. The
            // code is the only thing that tells them apart, so the body survives the mapping.
            case let .unauthorized(payload): throw failure(401, try? payload.body.json)
            case .forbidden: throw PerpsAPIError.unauthorized
            case let .conflict(payload): throw failure(409, try? payload.body.json)
            case let .internalServerError(payload): throw failure(500, try? payload.body.json)
            case let .serviceUnavailable(payload): throw failure(503, try? payload.body.json)
            case let .undocumented(statusCode, _): throw PerpsAPIError.badStatus(.undecoded(statusCode, message: "undocumented"))
            }
        }
    }

    func getDeposit(
        walletId: String,
        depositId: String
    ) async throws -> Components.Schemas.Deposit {
        try await retrying {
            let client = try await client(walletId: walletId)
            let response: Operations.getDeposit.Output
            do {
                response = try await client.getDeposit(
                    path: .init(deposit_id: depositId)
                )
            } catch {
                throw PerpsAPIError.transport(underlying: error)
            }
            switch response {
            case let .ok(ok): return try decode(ok.body.json)
            case let .badRequest(payload): throw status(400, payload)
            case .unauthorized(_), .forbidden: throw PerpsAPIError.unauthorized
            case .notFound: throw PerpsAPIError.notFound
            case let .internalServerError(payload): throw failure(500, try? payload.body.json)
            case let .serviceUnavailable(payload): throw failure(503, try? payload.body.json)
            case let .undocumented(statusCode, _): throw PerpsAPIError.badStatus(.undecoded(statusCode, message: "undocumented"))
            }
        }
    }

    func quoteDeposit(
        walletId: String,
        request: Components.Schemas.DepositQuoteRequest
    ) async throws -> Components.Schemas.DepositQuote {
        try await retrying {
            let client = try await client(walletId: walletId)
            let response: Operations.quoteDeposit.Output
            do {
                response = try await client.quoteDeposit(
                    body: .json(request)
                )
            } catch {
                throw PerpsAPIError.transport(underlying: error)
            }
            switch response {
            case let .ok(ok): return try decode(ok.body.json)
            // Nothing has moved yet, so the body is what tells an unsupported source asset
            // from a wrong amount — the two lead to different screens.
            case let .badRequest(payload): throw status(400, payload)
            case .unauthorized(_), .forbidden: throw PerpsAPIError.unauthorized
            case let .conflict(payload): throw failure(409, try? payload.body.json)
            case let .internalServerError(payload): throw failure(500, try? payload.body.json)
            case let .serviceUnavailable(payload): throw failure(503, try? payload.body.json)
            case let .undocumented(statusCode, _): throw PerpsAPIError.badStatus(.undecoded(statusCode, message: "undocumented"))
            }
        }
    }

    func quoteWithdraw(
        walletId: String,
        request: Components.Schemas.WithdrawQuoteRequest
    ) async throws -> Components.Schemas.WithdrawQuote {
        try await retrying {
            let client = try await client(walletId: walletId)
            let response: Operations.quoteWithdraw.Output
            do {
                response = try await client.quoteWithdraw(body: .json(request))
            } catch {
                throw PerpsAPIError.transport(underlying: error)
            }
            switch response {
            case let .ok(ok): return try decode(ok.body.json)
            case let .badRequest(payload): throw status(400, payload)
            case .unauthorized(_), .forbidden: throw PerpsAPIError.unauthorized
            case let .conflict(payload): throw failure(409, try? payload.body.json)
            case let .internalServerError(payload): throw failure(500, try? payload.body.json)
            case let .serviceUnavailable(payload): throw failure(503, try? payload.body.json)
            case let .undocumented(statusCode, _): throw PerpsAPIError.badStatus(.undecoded(statusCode, message: "undocumented"))
            }
        }
    }

    func getFundingStatus(
        walletId: String,
        executionId: String
    ) async throws -> Components.Schemas.FundingStatus {
        try await retrying {
            let client = try await client(walletId: walletId)
            let response: Operations.getFundingStatus.Output
            do {
                response = try await client.getFundingStatus(
                    path: .init(execution_id: executionId)
                )
            } catch {
                throw PerpsAPIError.transport(underlying: error)
            }
            switch response {
            case let .ok(ok): return try decode(ok.body.json)
            case let .badRequest(payload): throw status(400, payload)
            case .unauthorized(_), .forbidden: throw PerpsAPIError.unauthorized
            case let .internalServerError(payload): throw failure(500, try? payload.body.json)
            case let .serviceUnavailable(payload): throw failure(503, try? payload.body.json)
            case let .undocumented(statusCode, _): throw PerpsAPIError.badStatus(.undecoded(statusCode, message: "undocumented"))
            }
        }
    }

    func portfolio(walletId: String) async throws -> Components.Schemas.Portfolio {
        try await retrying {
            let client = try await client(walletId: walletId)
            let response: Operations.getPortfolio.Output
            do {
                response = try await client.getPortfolio()
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
            case let .internalServerError(payload):
                throw failure(500, try? payload.body.json)
            case let .serviceUnavailable(payload):
                throw failure(503, try? payload.body.json)
            case let .undocumented(statusCode, _):
                throw PerpsAPIError.badStatus(.undecoded(statusCode, message: "undocumented"))
            }
        }
    }

    func listOpenPositions(walletId: String) async throws -> Components.Schemas.OpenPositionsPage {
        let client = try await client(walletId: walletId)
        let response: Operations.listOpenPositions.Output
        do {
            response = try await client.listOpenPositions()
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
        try await retrying {
            let client = try await client(walletId: walletId)
            let response: Operations.getOpenPosition.Output
            do {
                response = try await client.getOpenPosition(
                    path: .init(id: id)
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
            case let .internalServerError(payload):
                throw failure(500, try? payload.body.json)
            case let .serviceUnavailable(payload):
                throw failure(503, try? payload.body.json)
            case let .undocumented(statusCode, _):
                throw PerpsAPIError.badStatus(.undecoded(statusCode, message: "undocumented"))
            }
        }
    }

    func getOrder(
        walletId: String,
        id: String
    ) async throws -> Components.Schemas.OrderDetail {
        try await retrying {
            let client = try await client(walletId: walletId)
            let response: Operations.getOrder.Output
            do {
                response = try await client.getOrder(
                    path: .init(id: id)
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
            case let .internalServerError(payload):
                throw failure(500, try? payload.body.json)
            case let .serviceUnavailable(payload):
                throw failure(503, try? payload.body.json)
            case let .undocumented(statusCode, _):
                throw PerpsAPIError.badStatus(.undecoded(statusCode, message: "undocumented"))
            }
        }
    }

    func positionState(
        walletId: String,
        id: String,
        clientOrderIndex: Int64?
    ) async throws -> Components.Schemas.PositionState {
        try await retrying {
            let client = try await client(walletId: walletId)
            let response: Operations.getPositionState.Output
            do {
                response = try await client.getPositionState(
                    path: .init(id: id),
                    query: .init(client_order_index: clientOrderIndex)
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
            case let .internalServerError(payload):
                throw failure(500, try? payload.body.json)
            case let .serviceUnavailable(payload):
                throw failure(503, try? payload.body.json)
            case let .undocumented(statusCode, _):
                throw PerpsAPIError.badStatus(.undecoded(statusCode, message: "undocumented"))
            }
        }
    }

    func withdrawals(walletId: String, cursor: String?) async throws -> Components.Schemas.ActivityPage {
        try await activityPage(walletId: walletId, query: .init(_type: .withdrawal, cursor: cursor, limit: 100))
    }

    private func activityPage(
        walletId: String,
        query: Operations.getActivity.Input.Query
    ) async throws -> Components.Schemas.ActivityPage {
        try await retrying {
            let client = try await client(walletId: walletId)
            let response: Operations.getActivity.Output
            do {
                response = try await client.getActivity(query: query)
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
            case let .internalServerError(payload):
                throw failure(500, try? payload.body.json)
            case let .serviceUnavailable(payload):
                throw failure(503, try? payload.body.json)
            case let .undocumented(statusCode, _):
                throw PerpsAPIError.badStatus(.undecoded(statusCode, message: "undocumented"))
            }
        }
    }
}

private extension PerpsAPIImplementation {
    func retrying<T>(_ operation: () async throws -> T) async throws -> T {
        try await MultichainRetry.run { () async throws(PerpsAPIError) -> T in
            do {
                return try await operation()
            } catch let error as PerpsAPIError {
                throw error
            } catch {
                throw .unknown(underlying: error)
            }
        }
    }

    func client(walletId: String) async throws -> Client {
        do {
            return try await makeClient(walletId)
        } catch let error as PerpsAPIError {
            throw error
        } catch {
            throw PerpsAPIError.badUrl(underlying: error)
        }
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

    /// The generated client throws on an error body it cannot decode, taking the status with it,
    /// so a refusal whose body did not arrive intact would read as a lost connection.
    func transportOrStatus(_ error: Error) -> PerpsAPIError {
        if let status = (error as? ClientError)?.response?.status.code, status >= 400 {
            return failure(status, nil)
        }
        return .transport(underlying: error)
    }

    func failure(_ httpStatus: Int, _ body: Components.Schemas.ErrorResponse?) -> PerpsAPIError {
        guard let body else {
            return .badStatus(.undecoded(httpStatus, message: "unreadable error body"))
        }
        return .badStatus(PerpsAPIFailure(httpStatus: httpStatus, body: body))
    }
}

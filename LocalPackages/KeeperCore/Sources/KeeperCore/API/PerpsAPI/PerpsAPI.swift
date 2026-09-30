import Foundation
import TKPerpsAPI

protocol PerpsAPI {
    func account(walletId: String) async throws -> Components.Schemas.Account

    func bindAccount(
        walletId: String,
        request: Components.Schemas.BindAccountRequest
    ) async throws -> Components.Schemas.Account

    func tradingScreen(
        walletId: String,
        marketId: Int64
    ) async throws -> Components.Schemas.TradingScreen

    func truncatedOrderBook(
        walletId: String,
        marketId: Int64,
        side: Operations.getTruncatedOrderBook.Input.Query.sidePayload,
        feeRate: String,
        notional: String
    ) async throws -> Components.Schemas.TruncatedOrderBook

    func nextNonce(
        walletId: String,
        apiKeyIndex: Int
    ) async throws -> Components.Schemas.NextNonce

    func sendTransactions(
        walletId: String,
        transactions: [Components.Schemas.SignedTransaction]
    ) async throws -> Components.Schemas.SendTransactionsResponse

    func portfolioScreen(walletId: String) async throws -> Components.Schemas.PortfolioScreen

    func listOpenPositions(walletId: String) async throws -> Components.Schemas.OpenPositionsPage

    func getOpenPosition(
        walletId: String,
        id: String
    ) async throws -> Components.Schemas.OpenPositionDetail

    func positionState(
        walletId: String,
        id: String,
        clientOrderIndex: Int64?
    ) async throws -> Components.Schemas.PositionState

    func activity(
        walletId: String,
        marketId: Int64?,
        limit: Int
    ) async throws -> Components.Schemas.ActivityPage
}

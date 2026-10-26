import Foundation
import TKPerpsAPI

protocol PerpsAPI {
    func account(walletId: String) async throws -> Components.Schemas.Account

    func integrator(walletId: String) async throws -> Components.Schemas.Integrator

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

    func issueReadOnlyToken(
        walletId: String,
        lighterAuth: String
    ) async throws -> Components.Schemas.IssuedRoToken

    /// Read by tk-perps with the read-only token it holds for the wallet.
    func accountTier(walletId: String) async throws -> Components.Schemas.AccountTier

    func changeAccountTier(
        walletId: String,
        lighterAuth: String,
        newTier: String
    ) async throws

    func sendTransactions(
        walletId: String,
        transactions: [Components.Schemas.SignedTransaction]
    ) async throws -> Components.Schemas.SendTransactionsResponse

    func openDeposit(
        walletId: String,
        request: Components.Schemas.OpenDepositRequest
    ) async throws -> Components.Schemas.Deposit

    func getDeposit(
        walletId: String,
        depositId: String
    ) async throws -> Components.Schemas.Deposit

    func quoteDeposit(
        walletId: String,
        request: Components.Schemas.DepositQuoteRequest
    ) async throws -> Components.Schemas.DepositQuote

    func quoteWithdraw(
        walletId: String,
        request: Components.Schemas.WithdrawQuoteRequest
    ) async throws -> Components.Schemas.WithdrawQuote

    func getFundingStatus(
        walletId: String,
        executionId: String
    ) async throws -> Components.Schemas.FundingStatus

    func portfolio(walletId: String) async throws -> Components.Schemas.Portfolio

    func listOpenPositions(walletId: String) async throws -> Components.Schemas.OpenPositionsPage

    func getOpenPosition(
        walletId: String,
        id: String
    ) async throws -> Components.Schemas.OpenPositionDetail

    func getOrder(
        walletId: String,
        id: String
    ) async throws -> Components.Schemas.OrderDetail

    func positionState(
        walletId: String,
        id: String,
        clientOrderIndex: Int64?
    ) async throws -> Components.Schemas.PositionState

    /// Withdrawals alone, newest first; `cursor` is the previous page's `next_cursor`.
    func withdrawals(walletId: String, cursor: String?) async throws -> Components.Schemas.ActivityPage
}
